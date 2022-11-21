use allo_isolate::Isolate;
use futures::future;
use log::error;
use log_err::{LogErrOption, LogErrResult};
use once_cell::sync::{Lazy, OnceCell};
use std::{
    ffi::{CStr, CString},
    io,
    os::raw::{self, c_char},
    path::Path,
    sync::Mutex,
};
use tokio::runtime::{Builder, Runtime};

#[cfg(target_os = "android")]
use log::Level;
#[cfg(not(target_os = "android"))]
use log::LevelFilter;

#[cfg(target_os = "android")]
use android_logger::Config;
#[cfg(not(target_os = "android"))]
use simplelog::{ColorChoice, TermLogger, TerminalMode};

mod calendar_db;
mod device_kms;
mod secure_local_storage;

use calendar_db::CalendarDb;
use secure_local_storage::SecureLocalStorage;

#[cfg(target_os = "android")]
use device_kms::android::AndroidKms;
#[cfg(not(target_os = "android"))]
use device_kms::desktop::EmptyKms;
use device_kms::DeviceKms;

static RUNTIME: Lazy<io::Result<Runtime>> = Lazy::new(|| {
    Builder::new_multi_thread()
        .worker_threads(4)
        .thread_name("flutterust")
        .build()
});

macro_rules! runtime {
    () => {
        match RUNTIME.as_ref() {
            Ok(rt) => rt,
            Err(_) => {
                return false;
            }
        }
    };
}

struct CalendarNative {
    secure_calendar_db: CalendarDb,
}

impl CalendarNative {
    const SECURE_LOCAL_STOAGE_FILE: &'static str = "secure_local_storage.db";

    const CALENDAR_DB_KEY: &'static str = "calendar_db_key";
    const CALENDAR_DB_FILE: &'static str = "calendar.db";

    pub fn new<P: AsRef<Path> + Clone>(data_dir: P) -> Self {
        #[cfg(target_os = "android")]
        let device_kms: Box<dyn DeviceKms> = Box::new(AndroidKms::new());
        #[cfg(not(target_os = "android"))]
        let device_kms: Box<dyn DeviceKms> = Box::new(EmptyKms::new());

        let data_dir = data_dir.as_ref();

        let mut secure_local_storage =
            SecureLocalStorage::new(data_dir.join(Self::SECURE_LOCAL_STOAGE_FILE), &device_kms)
                .unwrap();

        let password = Self::get_or_generate_calendar_db_key(&mut secure_local_storage);
        let calendar_db =
            CalendarDb::new(data_dir.join(Self::CALENDAR_DB_FILE), password).log_unwrap();

        CalendarNative {
            secure_calendar_db: calendar_db,
        }
    }

    fn get_or_generate_calendar_db_key(secure_local_storage: &mut SecureLocalStorage) -> Vec<u8> {
        let password: Option<Vec<u8>> = secure_local_storage.get(Self::CALENDAR_DB_KEY).unwrap();

        let password = password.unwrap_or_else(|| {
            let password = tink_core::subtle::random::get_random_bytes(32);

            secure_local_storage
                .set(Self::CALENDAR_DB_KEY, &password)
                .unwrap();

            password
        });

        password
    }
}

static CALENDAR_NATIVE: OnceCell<Mutex<CalendarNative>> = OnceCell::new();

fn calendar_native() -> &'static Mutex<CalendarNative> {
    CALENDAR_NATIVE
        .get()
        .log_expect("calendar native is not initialized")
}

fn setup_logger() {
    #[cfg(target_os = "android")]
    android_logger::init_once(
        Config::default()
            .with_min_level(Level::Info)
            .with_tag("flutterust"),
    );

    #[cfg(not(target_os = "android"))]
    TermLogger::init(
        LevelFilter::Info,
        simplelog::Config::default(),
        TerminalMode::Mixed,
        ColorChoice::Auto,
    )
    .unwrap();
}

#[no_mangle]
pub extern "C" fn init(port: i64, data_dir: *const c_char) -> bool {
    setup_logger();

    tink_aead::init();
    tink_daead::init();

    let data_dir = unsafe { CStr::from_ptr(data_dir) }.to_str().log_unwrap();

    let rt = runtime!();
    let task = Isolate::new(port).task(future::lazy(move |_| {
        let _ = CALENDAR_NATIVE
            .set(Mutex::new(CalendarNative::new(data_dir)))
            .map_err(|_| {
                error!("init calendar native failed");
            });

        true
    }));
    rt.spawn(task);

    true
}

pub extern "C" fn destory_c_string(string: *mut c_char) {
    let _ = unsafe { CString::from_raw(string) };
}

#[no_mangle]
pub extern "C" fn fetch_event(
    port: i64,
    start_time: *const c_char,
    end_time: *const c_char,
) -> bool {
    let start_time = unsafe { CStr::from_ptr(start_time) }.to_str().log_unwrap();
    let end_time = unsafe { CStr::from_ptr(end_time) }.to_str().log_unwrap();

    let rt = runtime!();
    let task = Isolate::new(port).task(future::lazy(|_| {
        let result = if let Ok(c) = calendar_native().lock() {
            c.secure_calendar_db
                .fetch_calendar_event(start_time, end_time)
                .unwrap_or_else(|_| vec![])
        } else {
            vec![]
        };

        let result = serde_json::to_string(&result).log_unwrap();

        result
    }));
    rt.spawn(task);

    true
}

#[no_mangle]
pub extern "C" fn add_event(port: i64, event: *const raw::c_char) -> bool {
    let event = unsafe { CStr::from_ptr(event) }.to_str().log_unwrap();

    let rt = runtime!();
    let task = Isolate::new(port).task(future::lazy(|_| {
        if let Ok(c) = calendar_native().lock() {
            let event: serde_json::Value = serde_json::from_str(event).log_unwrap();

            let _ = c.secure_calendar_db.add_event(event);
        }

        true
    }));
    rt.spawn(task);

    true
}

#[no_mangle]
pub extern "C" fn delete_event(port: i64, id: *const raw::c_char) -> bool {
    let id = unsafe { CStr::from_ptr(id) }.to_str().log_unwrap();

    let rt = runtime!();
    let task = Isolate::new(port).task(future::lazy(|_| {
        if let Ok(c) = calendar_native().lock() {
            let _ = c.secure_calendar_db.delete_event(id);
        }
        true
    }));
    rt.spawn(task);

    true
}
