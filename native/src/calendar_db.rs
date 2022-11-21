use std::path::Path;
use std::sync::Mutex;

use anyhow::{anyhow, Result};

use chrono::{DateTime, Utc};
use juniper::{
    DefaultScalarValue, EmptySubscription, ExecutionError, FieldResult, GraphQLInputObject,
    GraphQLObject, RootNode, Variables,
};
use log::info;
use log_err::LogErrResult;
use nosqlite::{field, Field, Filter, Key, KeyTable};
use rusqlite::{params, types::Value, Connection};
use serde::{Deserialize, Serialize};

type Schema = RootNode<'static, Query, Mutation, EmptySubscription<CalendarDb>>;

pub struct CalendarDb {
    db: Mutex<nosqlite::Connection>,
}

impl CalendarDb {
    pub fn new<P: AsRef<Path> + Clone>(file_path: P, password: Vec<u8>) -> Result<CalendarDb> {
        if password.len() != 32 {
            panic!("calendar db password lenght is correct.");
        }

        let db = Connection::open(file_path).log_unwrap();

        Self::configure(&db, password)?;

        let db = nosqlite::Connection::from_rusqlite(db);

        Ok(CalendarDb { db: Mutex::new(db) })
    }

    fn configure(db: &rusqlite::Connection, password: Vec<u8>) -> Result<()> {
        let hex_pw = hex::encode(password);

        // set password
        db.execute_batch(&format!(
            r#"
            PRAGMA key="x'{}'";
           "#,
            hex_pw
        ))?;

        Self::set_version(db)?;

        Ok(())
    }

    fn set_version(db: &rusqlite::Connection) -> Result<()> {
        let version: i32 = db.query_row("PRAGMA user_version", params![], |row| row.get(0))?;

        info!("calendar db version {}", version);

        if version < 1 {
            db.execute(&format!("PRAGMA user_version='{}'", 1), params![])?;
        }

        Ok(())
    }

    pub fn query(
        &self,
        ops: &str,
        variables: Option<&str>,
    ) -> Result<(juniper::Value, Vec<ExecutionError<DefaultScalarValue>>)> {
        let variables: Variables = variables
            .map(|v| serde_json::from_str(v).log_unwrap())
            .unwrap_or_else(|| Variables::new());

        juniper::execute_sync(
            ops,
            None,
            &Schema::new(Query, Mutation, EmptySubscription::new()),
            &variables,
            &self,
        )
        .map_err(|e| anyhow!("{}", e.to_string()))
    }
}

struct DateTimeField(Field);

impl Key for DateTimeField {
    fn key(&self, data_key: &str) -> String {
        format!("cast(strftime('%s', {}) as integer)", self.0.key(data_key))
    }
}

fn date_field(field_name: &str) -> DateTimeField {
    DateTimeField(field(field_name))
}

#[derive(GraphQLInputObject, Clone, Serialize)]
struct NewEvent {
    uid: String,
    summary: String,
    start: chrono::DateTime<Utc>,
    description: Option<String>,
}

impl NewEvent {
    fn to_event(&self) -> Event {
        Event {
            uid: self.uid.clone(),
            summary: self.summary.clone(),
            start: self.start.clone(),
            description: self.description.clone(),
        }
    }
}

#[derive(GraphQLObject, Clone, Deserialize, Debug, PartialEq)]
struct Event {
    uid: String,
    summary: String,
    start: chrono::DateTime<Utc>,
    description: Option<String>,
}

impl Event {
    const TABLE: &'static str = "calendar_events";

    fn fetch(db: &CalendarDb, start: DateTime<Utc>, end: DateTime<Utc>) -> FieldResult<Vec<Event>> {
        let db = db.db.lock()?;

        let calendar_events: KeyTable<String> = db.key_table(Self::TABLE)?;

        // We used DateTime to validate the `start` and `end` times.
        // So below query is safe against SQL injection.
        let result: Vec<Event> = calendar_events
            .as_ref()
            .iter()
            .filter(
                date_field("start")
                    .gte(start.timestamp())
                    .and(date_field("start").lte(end.timestamp())),
            )
            .data(&*db)?;

        Ok(result)
    }

    fn add(db: &CalendarDb, event: NewEvent) -> FieldResult<Event> {
        let db = db.db.lock()?;

        let calendar_events: KeyTable<String> = db.key_table(Self::TABLE)?;

        // has id in database
        if calendar_events
            .as_ref()
            .get(event.uid.clone())
            .id(&*db)?
            .is_some()
        {
            let table_name = calendar_events.0.name;

            // Use rusqlite instead of nosqlite to avoid SQL injection
            db.as_ref().execute(
                &format!(
                    "UPDATE {} SET data = json_patch(data, :value) where id = :id",
                    table_name,
                ),
                &[
                    (":value", &Value::Text(serde_json::to_string(&event)?)),
                    (":id", &event.uid.clone().into()),
                ],
            )?;
        } else {
            calendar_events.insert(event.uid.clone(), event.clone(), &*db)?;
        }

        Ok(event.to_event())
    }

    fn delete(db: &CalendarDb, uid: String) -> FieldResult<String> {
        let db = db.db.lock()?;

        let calendar_events: KeyTable<String> = db.key_table(Self::TABLE)?;

        let table_name = calendar_events.0.name;

        // Use rusqlite instead of nosqlite to avoid SQL injection
        db.as_ref().execute(
            &format!("DELETE FROM {} WHERE id = ?1", table_name),
            params![uid],
        )?;

        Ok(uid)
    }
}

#[derive(GraphQLInputObject, Clone, Serialize)]
struct NewInboxNote {
    id: String,
    content: String,
    time: chrono::DateTime<Utc>,
}

impl NewInboxNote {
    fn to_inbox_note(&self) -> InboxNote {
        InboxNote {
            id: self.id.clone(),
            content: self.content.clone(),
            time: self.time.clone(),
        }
    }
}

#[derive(GraphQLObject, Clone, Deserialize, Debug, PartialEq)]
struct InboxNote {
    id: String,
    content: String,
    time: chrono::DateTime<Utc>,
}

impl InboxNote {
    const TABLE: &'static str = "calendar_inbox_notes";

    fn fetch(db: &CalendarDb) -> FieldResult<Vec<InboxNote>> {
        let db = db.db.lock()?;

        let calendar_events: KeyTable<String> = db.key_table(Self::TABLE)?;

        let result: Vec<InboxNote> = calendar_events.as_ref().iter().data(&*db)?;

        Ok(result)
    }

    fn add(db: &CalendarDb, note: NewInboxNote) -> FieldResult<InboxNote> {
        let db = db.db.lock()?;

        let calendar_events: KeyTable<String> = db.key_table(Self::TABLE)?;

        calendar_events.insert(note.id.clone(), note.clone(), &*db)?;

        Ok(note.to_inbox_note())
    }

    fn delete(db: &CalendarDb, id: String) -> FieldResult<String> {
        let db = db.db.lock()?;

        let calendar_events: KeyTable<String> = db.key_table(Self::TABLE)?;

        let table_name = calendar_events.0.name;

        // Use rusqlite instead of nosqlite to avoid SQL injection
        db.as_ref().execute(
            &format!("DELETE FROM {} WHERE id = ?1", table_name),
            params![id],
        )?;

        Ok(id)
    }
}

struct Query;

#[juniper::graphql_object(Context = CalendarDb)]
impl Query {
    fn fetch_event(
        db: &CalendarDb,
        start: DateTime<Utc>,
        end: DateTime<Utc>,
    ) -> FieldResult<Vec<Event>> {
        Event::fetch(db, start, end)
    }

    fn fetch_inbox_note(db: &CalendarDb) -> FieldResult<Vec<InboxNote>> {
        InboxNote::fetch(db)
    }
}

struct Mutation;

#[juniper::graphql_object(Context = CalendarDb)]
impl Mutation {
    pub fn add_event(db: &CalendarDb, event: NewEvent) -> FieldResult<Event> {
        Event::add(db, event)
    }

    pub fn delete_event(db: &CalendarDb, uid: String) -> FieldResult<String> {
        Event::delete(db, uid)
    }

    pub fn add_inbox_note(db: &CalendarDb, note: NewInboxNote) -> FieldResult<InboxNote> {
        InboxNote::add(db, note)
    }

    pub fn delete_inbox_note(db: &CalendarDb, id: String) -> FieldResult<String> {
        InboxNote::delete(db, id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    use tempfile::tempdir;

    #[test]
    fn it_works() {
        let tmp_dir = tempdir().unwrap();

        let db_path = tmp_dir.path().join("calendar.db");

        let password = tink_core::subtle::random::get_random_bytes(32);

        let calendar_db = CalendarDb::new(db_path, password).unwrap();

        let event1 = NewEvent {
            uid: "id1".to_owned(),
            summary: "Meeting 1".to_owned(),
            start: "2022-01-02T13:00:00Z".parse().unwrap(),
            description: None,
        };

        Event::add(&calendar_db, event1.clone()).unwrap();

        let event2 = NewEvent {
            uid: "id2".to_owned(),
            summary: "Meeting 1".to_owned(),
            start: "2022-01-02T13:00:00Z".parse().unwrap(),
            description: None,
        };

        Event::add(&calendar_db, event2.clone()).unwrap();

        let earlier_event = NewEvent {
            uid: "id3".to_owned(),
            summary: "Meeting 1".to_owned(),
            start: "2022-12-29T13:00:00Z".parse().unwrap(),
            description: None,
        };

        Event::add(&calendar_db, earlier_event.clone()).unwrap();

        let later_event = NewEvent {
            uid: "id4".to_owned(),
            summary: "Meeting 1".to_owned(),
            start: "2022-01-04T13:00:00Z".parse().unwrap(),
            description: None,
        };

        Event::add(&calendar_db, later_event.clone()).unwrap();

        let events = Event::fetch(
            &calendar_db,
            "2022-01-01T13:00:00Z".parse().unwrap(),
            "2022-01-03T13:00:00Z".parse().unwrap(),
        )
        .unwrap();

        assert_eq!(events.len(), 2);
        assert_eq!(events[0], event1.to_event());
        assert_eq!(events[1], event2.to_event());
    }

    #[test]
    fn reload_db() {
        let tmp_dir = tempdir().unwrap();

        let db_path = tmp_dir.path().join("calendar.db");

        let password = tink_core::subtle::random::get_random_bytes(32);

        {
            let calendar_db = CalendarDb::new(db_path.clone(), password.clone()).unwrap();

            let v = NewEvent {
                uid: "id1".to_owned(),
                summary: "Meeting 1".to_owned(),
                start: "2022-01-02T13:00:00Z".parse().unwrap(),
                description: None,
            };

            Event::add(&calendar_db, v.clone()).unwrap();

            let events = Event::fetch(
                &calendar_db,
                "2022-01-01T13:00:00Z".parse().unwrap(),
                "2022-01-03T13:00:00Z".parse().unwrap(),
            )
            .unwrap();

            assert_eq!(events.len(), 1);
            assert_eq!(events[0], v.to_event());
        }
        {
            let calendar_db = CalendarDb::new(db_path, password).unwrap();

            let v = NewEvent {
                uid: "id1".to_owned(),
                summary: "Meeting 1".to_owned(),
                start: "2022-01-02T13:00:00Z".parse().unwrap(),
                description: None,
            };

            let events = Event::fetch(
                &calendar_db,
                "2022-01-01T13:00:00Z".parse().unwrap(),
                "2022-01-03T13:00:00Z".parse().unwrap(),
            )
            .unwrap();

            assert_eq!(events.len(), 1);
            assert_eq!(events[0], v.to_event());
        }
    }

    #[test]
    fn update() {
        let tmp_dir = tempdir().unwrap();

        let db_path = tmp_dir.path().join("calendar.db");

        let password = tink_core::subtle::random::get_random_bytes(32);
        let calendar_db = CalendarDb::new(db_path, password).unwrap();

        let event = NewEvent {
            uid: "id1".to_owned(),
            summary: "Meeting 1".to_owned(),
            start: "2022-01-02T13:00:00Z".parse().unwrap(),
            description: None,
        };

        Event::add(&calendar_db, event.clone()).unwrap();

        let events = Event::fetch(
            &calendar_db,
            "2022-01-01T13:00:00Z".parse().unwrap(),
            "2022-01-03T13:00:00Z".parse().unwrap(),
        )
        .unwrap();

        assert_eq!(events.len(), 1);
        assert_eq!(events[0], event.to_event());

        let new_event = NewEvent {
            uid: "id1".to_owned(),
            summary: "Meeting 2".to_owned(),
            start: "2022-01-02T13:00:00Z".parse().unwrap(),
            description: None,
        };

        Event::add(&calendar_db, new_event.clone()).unwrap();

        let events = Event::fetch(
            &calendar_db,
            "2022-01-01T13:00:00Z".parse().unwrap(),
            "2022-01-03T13:00:00Z".parse().unwrap(),
        )
        .unwrap();

        assert_eq!(events.len(), 1);
        assert_eq!(events[0], new_event.to_event());
    }

    #[test]
    fn detele() {
        let tmp_dir = tempdir().unwrap();

        let db_path = tmp_dir.path().join("calendar.db");

        let password = tink_core::subtle::random::get_random_bytes(32);
        let calendar_db = CalendarDb::new(db_path, password).unwrap();

        let event1 = NewEvent {
            uid: "id1".to_owned(),
            summary: "Meeting 1".to_owned(),
            start: "2022-01-02T13:00:00Z".parse().unwrap(),
            description: None,
        };

        Event::add(&calendar_db, event1.clone()).unwrap();

        let event2 = NewEvent {
            uid: "id2".to_owned(),
            summary: "Meeting 2".to_owned(),
            start: "2022-01-02T13:00:00Z".parse().unwrap(),
            description: None,
        };

        Event::add(&calendar_db, event2.clone()).unwrap();

        let events = Event::fetch(
            &calendar_db,
            "2022-01-01T13:00:00Z".parse().unwrap(),
            "2022-01-03T13:00:00Z".parse().unwrap(),
        )
        .unwrap();

        assert_eq!(events.len(), 2);
        assert_eq!(events[0], event1.to_event());

        Event::delete(&calendar_db, "id1".to_owned()).unwrap();

        let events = Event::fetch(
            &calendar_db,
            "2022-01-01T13:00:00Z".parse().unwrap(),
            "2022-01-03T13:00:00Z".parse().unwrap(),
        )
        .unwrap();

        assert_eq!(events.len(), 1);
        assert_eq!(events[0], event2.to_event());
    }

    #[test]
    fn query_then_add() {
        let tmp_dir = tempdir().unwrap();

        let db_path = tmp_dir.path().join("calendar.db");

        let password = tink_core::subtle::random::get_random_bytes(32);
        let calendar_db = CalendarDb::new(db_path, password).unwrap();

        let events = Event::fetch(
            &calendar_db,
            "2022-01-01T13:00:00Z".parse().unwrap(),
            "2022-01-03T13:00:00Z".parse().unwrap(),
        )
        .unwrap();

        assert_eq!(events.len(), 0);

        let event1 = NewEvent {
            uid: "id1".to_owned(),
            summary: "Meeting 1".to_owned(),
            start: "2022-01-02T13:00:00Z".parse().unwrap(),
            description: None,
        };

        Event::add(&calendar_db, event1.clone()).unwrap();

        let events = Event::fetch(
            &calendar_db,
            "2022-01-01T13:00:00Z".parse().unwrap(),
            "2022-01-03T13:00:00Z".parse().unwrap(),
        )
        .unwrap();

        assert_eq!(events.len(), 1);
        assert_eq!(events[0], event1.to_event());
    }
}
