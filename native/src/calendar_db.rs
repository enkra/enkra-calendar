use std::path::Path;

use anyhow::Result;

use chrono::DateTime;
use log::info;
use log_err::{LogErrOption, LogErrResult};
use nosqlite::{field, Field, Filter, Key, KeyTable};
use rusqlite::{params, types::Value, Connection};

pub struct CalendarDb {
    db: nosqlite::Connection,
}

impl CalendarDb {
    pub fn new<P: AsRef<Path> + Clone>(file_path: P, password: Vec<u8>) -> Result<CalendarDb> {
        if password.len() != 32 {
            panic!("calendar db password lenght is correct.");
        }

        let db = Connection::open(file_path).log_unwrap();

        Self::configure(&db, password)?;

        let db = nosqlite::Connection::from_rusqlite(db);

        Ok(CalendarDb { db })
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
}

impl CalendarDb {
    pub fn fetch_calendar_event(
        &self,
        start_time: &str,
        end_time: &str,
    ) -> Result<Vec<serde_json::Value>> {
        let calendar_events: KeyTable<String> = self.db.key_table("calendar_events")?;

        let start_time = DateTime::parse_from_rfc3339(start_time)?;
        let end_time = DateTime::parse_from_rfc3339(end_time)?;

        // We used DateTime to validate the `start` and `end` times.
        // So below query is safe against SQL injection.
        let result: Vec<serde_json::Value> = calendar_events
            .as_ref()
            .iter()
            .filter(
                date_field("start")
                    .gte(start_time.timestamp())
                    .and(date_field("start").lte(end_time.timestamp())),
            )
            .data(&self.db)?;

        Ok(result)
    }

    pub fn add_event(&self, event: serde_json::Value) -> Result<()> {
        let calendar_events: KeyTable<String> = self.db.key_table("calendar_events".to_owned())?;

        let id = event["uid"].as_str().log_unwrap().to_string();

        // has id in database
        if calendar_events
            .as_ref()
            .get(id.clone())
            .id(&self.db)?
            .is_some()
        {
            let table_name = calendar_events.0.name;

            // Use rusqlite instead of nosqlite to avoid SQL injection
            self.db.as_ref().execute(
                &format!(
                    "UPDATE {} SET data = json_patch(data, :value) where id = :id",
                    table_name,
                ),
                &[
                    (":value", &Value::Text(serde_json::to_string(&event)?)),
                    (":id", &id.into()),
                ],
            )?;
        } else {
            calendar_events.insert(id, event, &self.db)?;
        }

        Ok(())
    }

    pub fn delete_event(&self, event_id: &str) -> Result<()> {
        let calendar_events: KeyTable<String> = self.db.key_table("calendar_events".to_owned())?;

        let table_name = calendar_events.0.name;

        // Use rusqlite instead of nosqlite to avoid SQL injection
        self.db.as_ref().execute(
            &format!("DELETE FROM {} WHERE id = ?1", table_name),
            params![event_id],
        )?;

        Ok(())
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

#[cfg(test)]
mod tests {
    use super::*;

    use serde_json::json;
    use tempfile::tempdir;

    #[test]
    fn it_works() {
        let tmp_dir = tempdir().unwrap();

        let db_path = tmp_dir.path().join("calendar.db");

        let password = tink_core::subtle::random::get_random_bytes(32);

        let calendar_db = CalendarDb::new(db_path, password).unwrap();
        let event1 = json!({
            "uid": "id1",
            "summary": "Meeting 1",
            "start": "2022-01-02T13:00:00Z",
        });

        calendar_db.add_event(event1.clone()).unwrap();

        let event2 = json!({
            "uid": "id2",
            "summary": "Meeting 1",
            "start": "2022-01-02T13:00:00Z",
        });

        calendar_db.add_event(event2.clone()).unwrap();

        let earlier_event = json!({
            "uid": "id3",
            "summary": "Meeting 1",
            "start": "2021-12-29T13:00:00Z",
        });

        calendar_db.add_event(earlier_event.clone()).unwrap();

        let later_event = json!({
            "uid": "id4",
            "summary": "Meeting 1",
            "start": "2022-01-04T13:00:00Z",
        });

        calendar_db.add_event(later_event.clone()).unwrap();

        let events = calendar_db
            .fetch_calendar_event("2022-01-01T13:00:00Z", "2022-01-03T13:00:00Z")
            .unwrap();

        assert_eq!(events.len(), 2);
        assert_eq!(events[0], event1);
        assert_eq!(events[1], event2);
    }

    #[test]
    fn reload_db() {
        let tmp_dir = tempdir().unwrap();

        let db_path = tmp_dir.path().join("calendar.db");

        let password = tink_core::subtle::random::get_random_bytes(32);

        {
            let calendar_db = CalendarDb::new(db_path.clone(), password.clone()).unwrap();
            let v = json!({
                "uid": "id1",
                "summary": "Meeting 1",
                "start": "2022-01-02T13:00:00Z",
            });

            calendar_db.add_event(v.clone()).unwrap();

            let events = calendar_db
                .fetch_calendar_event("2022-01-01T13:00:00Z", "2022-01-03T13:00:00Z")
                .unwrap();

            assert_eq!(events.len(), 1);
            assert_eq!(events[0], v);
        }
        {
            let calendar_db = CalendarDb::new(db_path, password).unwrap();
            let v = json!({
                "uid": "id1",
                "summary": "Meeting 1",
                "start": "2022-01-02T13:00:00Z",
            });

            let events = calendar_db
                .fetch_calendar_event("2022-01-01T13:00:00Z", "2022-01-03T13:00:00Z")
                .unwrap();

            assert_eq!(events.len(), 1);
            assert_eq!(events[0], v);
        }
    }

    #[test]
    fn update() {
        let tmp_dir = tempdir().unwrap();

        let db_path = tmp_dir.path().join("calendar.db");

        let password = tink_core::subtle::random::get_random_bytes(32);
        let calendar_db = CalendarDb::new(db_path, password).unwrap();

        let event = json!({
            "uid": "id1",
            "summary": "Meeting 1",
            "start": "2022-01-02T13:00:00Z",
        });

        calendar_db.add_event(event.clone()).unwrap();

        let events = calendar_db
            .fetch_calendar_event("2022-01-01T13:00:00Z", "2022-01-03T13:00:00Z")
            .unwrap();

        assert_eq!(events.len(), 1);
        assert_eq!(events[0], event);

        let new_event = json!({
            "uid": "id1",
            "summary": "Meeting 2",
            "start": "2022-01-02T13:00:00Z",
        });

        calendar_db.add_event(new_event.clone()).unwrap();

        let events = calendar_db
            .fetch_calendar_event("2022-01-01T13:00:00Z", "2022-01-03T13:00:00Z")
            .unwrap();

        assert_eq!(events.len(), 1);
        assert_eq!(events[0], new_event);
    }

    #[test]
    fn detele() {
        let tmp_dir = tempdir().unwrap();

        let db_path = tmp_dir.path().join("calendar.db");

        let password = tink_core::subtle::random::get_random_bytes(32);
        let calendar_db = CalendarDb::new(db_path, password).unwrap();

        let event1 = json!({
            "uid": "id1",
            "summary": "Meeting 1",
            "start": "2022-01-02T13:00:00Z",
        });

        calendar_db.add_event(event1.clone()).unwrap();

        let event2 = json!({
            "uid": "id2",
            "summary": "Meeting 2",
            "start": "2022-01-02T13:00:00Z",
        });

        calendar_db.add_event(event2.clone()).unwrap();

        let events = calendar_db
            .fetch_calendar_event("2022-01-01T13:00:00Z", "2022-01-03T13:00:00Z")
            .unwrap();

        assert_eq!(events.len(), 2);
        assert_eq!(events[0], event1);

        calendar_db.delete_event("id1").unwrap();

        let events = calendar_db
            .fetch_calendar_event("2022-01-01T13:00:00Z", "2022-01-03T13:00:00Z")
            .unwrap();

        assert_eq!(events.len(), 1);
        assert_eq!(events[0], event2);
    }

    #[test]
    fn query_then_add() {
        let tmp_dir = tempdir().unwrap();

        let db_path = tmp_dir.path().join("calendar.db");

        let password = tink_core::subtle::random::get_random_bytes(32);
        let calendar_db = CalendarDb::new(db_path, password).unwrap();

        let events = calendar_db
            .fetch_calendar_event("2022-01-01T13:00:00Z", "2022-01-03T13:00:00Z")
            .unwrap();

        assert_eq!(events.len(), 0);

        let event1 = json!({
            "uid": "id1",
            "summary": "Meeting 1",
            "start": "2022-01-02T13:00:00Z",
        });

        calendar_db.add_event(event1.clone()).unwrap();

        let events = calendar_db
            .fetch_calendar_event("2022-01-01T13:00:00Z", "2022-01-03T13:00:00Z")
            .unwrap();

        assert_eq!(events.len(), 1);
        assert_eq!(events[0], event1);
    }
}
