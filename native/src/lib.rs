use allo_isolate::Isolate;
use futures::future;
use log::{error, info};
use log_err::{LogErrOption, LogErrResult};
use once_cell::sync::{Lazy, OnceCell};
use std::{
    ffi::{CStr, CString},
    io,
    os::raw::{self, c_char},
    path::Path,
    ptr::NonNull,
};
use tokio::runtime::{Builder, Runtime};

#[cfg(target_os = "android")]
use log::Level;
#[cfg(not(target_os = "android"))]
use log::LevelFilter;

#[cfg(target_os = "android")]
use android_logger::Config;
#[cfg(target_os = "ios")]
use oslog::OsLogger;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
use simplelog::{ColorChoice, TermLogger, TerminalMode};

mod calendar_db;
mod device_kms;
mod secure_local_storage;

use calendar_db::CalendarDb;
use secure_local_storage::SecureLocalStorage;

#[cfg(target_os = "android")]
use device_kms::android::AndroidKms;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
use device_kms::fallback::EmptyKms;
#[cfg(target_os = "ios")]
use device_kms::ios::IosKms;
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
                return 1;
            }
        }
    };
}

struct CalendarNative {
    secure_calendar_db: CalendarDb,
}

impl CalendarNative {
    const MASTER_KEY_FILE: &'static str = "master_key";

    const SECURE_LOCAL_STOAGE_FILE: &'static str = "vault.db";

    const CALENDAR_DB_KEY: &'static str = "calendar_db_key";
    const CALENDAR_DB_FILE: &'static str = "calendar.db";

    pub fn new<P: AsRef<Path> + Clone>(data_dir: P) -> Self {
        info!("CalendarNative new");
        let mut data_dir = data_dir.as_ref().to_path_buf();

        data_dir.push("data");

        if !data_dir.exists() {
            std::fs::create_dir_all(&data_dir).log_expect(&format!(
                "Create data_dir {} failed",
                data_dir.to_string_lossy()
            ));
        }

        let device_kms = Self::build_device_kms();
        device_kms.register_kms_client();

        // value.db is to store calendar app secrets such as sqlite db key.
        // Don't store app config preferences in it. Use a separate SecureLocalStorage
        // to store them.
        let mut vault = SecureLocalStorage::new_with_kms(
            data_dir.join(Self::SECURE_LOCAL_STOAGE_FILE),
            &device_kms,
            data_dir.join(Self::MASTER_KEY_FILE),
        )
        .log_unwrap();

        let password = Self::get_or_generate_calendar_db_key(&mut vault);
        let calendar_db =
            CalendarDb::new(data_dir.join(Self::CALENDAR_DB_FILE), password).log_unwrap();

        CalendarNative {
            secure_calendar_db: calendar_db,
        }
    }

    fn build_device_kms() -> Box<dyn DeviceKms> {
        #[cfg(target_os = "android")]
        let device_kms: Box<dyn DeviceKms> = Box::new(AndroidKms::new());
        #[cfg(target_os = "ios")]
        let device_kms: Box<dyn DeviceKms> = Box::new(IosKms::new());
        #[cfg(not(any(target_os = "android", target_os = "ios")))]
        let device_kms: Box<dyn DeviceKms> = Box::new(EmptyKms::new());

        device_kms
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

static CALENDAR_NATIVE: OnceCell<CalendarNative> = OnceCell::new();

fn calendar_native() -> &'static CalendarNative {
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
    #[cfg(target_os = "ios")]
    OsLogger::new("io.enkra.calendar")
        .level_filter(LevelFilter::Info)
        .init()
        .unwrap();

    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    TermLogger::init(
        LevelFilter::Info,
        simplelog::Config::default(),
        TerminalMode::Mixed,
        ColorChoice::Auto,
    )
    .unwrap();
}

#[no_mangle]
pub extern "C" fn calendar_init(port: i64, data_dir: *const c_char) -> i32 {
    setup_logger();

    tink_aead::init();
    tink_daead::init();

    let data_dir = unsafe { CStr::from_ptr(data_dir) }.to_str().log_unwrap();

    let rt = runtime!();
    let task = Isolate::new(port).task(future::lazy(move |_| {
        let _ = CALENDAR_NATIVE.get_or_init(|| CalendarNative::new(data_dir));

        true
    }));
    rt.spawn(task);

    0
}

pub extern "C" fn destory_c_string(string: *mut c_char) {
    let _ = unsafe { CString::from_raw(string) };
}

#[no_mangle]
pub extern "C" fn calendar_db_graphql(
    port: i64,
    ops: *const raw::c_char,
    variables: Option<NonNull<raw::c_char>>,
) -> i32 {
    let ops = unsafe { CStr::from_ptr(ops) }.to_str().log_unwrap();

    let variables = variables.map(|v| unsafe { CStr::from_ptr(v.as_ptr()) }.to_str().log_unwrap());

    let rt = runtime!();

    rt.spawn(async move {
        let result = calendar_native()
            .secure_calendar_db
            .query(ops, variables)
            .map_err(|e| {
                error!("graphql error {}", e);
            })
            .map(|(value, _)| {
                let result = serde_json::to_string(&value).log_unwrap();
                return result;
            })
            .unwrap_or_else(|_| "{}".to_owned());

        Isolate::new(port).post(result);
    });

    0
}
