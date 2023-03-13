use libc::{input_event, timeval};
use std::{
    ffi::CStr,
    fs::File,
    io,
    os::{
        raw::{c_char, c_int, c_uint},
        unix::io::AsRawFd,
    },
};

bitflags::bitflags! {
pub struct ReadFlag: c_uint {
    const SYNC = 1;
    const NORMAL = 2;
    const FORCE_SYNC = 4;
    const BLOCKING = 8;
}
}

fn result<T>(value: T, rc: c_int) -> io::Result<T> {
    if rc != 0 {
        Err(io::Error::from_raw_os_error(-rc))
    } else {
        Ok(value)
    }
}

#[allow(unused_unsafe)]
unsafe fn c_char_ptr_to_string(cptr: *const c_char) -> String {
    let c_str: &CStr = unsafe { CStr::from_ptr(cptr) };
    c_str.to_string_lossy().to_string()
}

#[repr(C)]
#[derive(Debug)]
struct libevdev {
    _unused: [u8; 0],
}

extern "C" {
    fn libevdev_new_from_fd(fd: c_int, dev: *mut *mut libevdev) -> c_int;
    fn libevdev_free(dev: *mut libevdev);
    fn libevdev_get_id_vendor(dev: *const libevdev) -> c_int;
    fn libevdev_get_id_product(dev: *const libevdev) -> c_int;
    fn libevdev_get_name(dev: *const libevdev) -> *const c_char;
    fn libevdev_next_event(dev: *mut libevdev, flags: c_uint, ev: *mut input_event) -> c_int;
}

pub const LIBEVDEV_READ_STATUS_SUCCESS: c_int = 0;
pub const LIBEVDEV_READ_STATUS_SYNC: c_int = 1;

#[allow(dead_code)] // file never used
pub struct Dev {
    file: File,
    raw: *mut libevdev,
}

impl Dev {
    pub fn vendor_id(&self) -> u16 {
        (unsafe { libevdev_get_id_vendor(self.raw) }) as u16
    }
    pub fn product_id(&self) -> u16 {
        (unsafe { libevdev_get_id_product(self.raw) }) as u16
    }
    pub fn name(&self) -> String {
        unsafe { c_char_ptr_to_string(libevdev_get_name(self.raw)) }
    }
    pub fn next_event(&self, flags: ReadFlag) -> io::Result<Option<input_event>> {
        let mut ie: input_event = input_event {
            time: timeval {
                tv_sec: 0,
                tv_usec: 0,
            },
            type_: 0,
            code: 0,
            value: 0,
        };

        let rc: c_int = unsafe { libevdev_next_event(self.raw, flags.bits(), &mut ie) };

        match rc {
            LIBEVDEV_READ_STATUS_SUCCESS => Ok(Some(ie)),
            LIBEVDEV_READ_STATUS_SYNC => Ok(None),
            _ => Err(io::Error::from_raw_os_error(-rc)),
        }
    }
}

impl TryFrom<File> for Dev {
    type Error = io::Error;
    fn try_from(file: File) -> io::Result<Self> {
        let mut libevdev = std::ptr::null_mut();
        let rc: c_int = unsafe { libevdev_new_from_fd(file.as_raw_fd(), &mut libevdev) };

        result(
            Self {
                file,
                raw: libevdev,
            },
            rc,
        )
    }
}

impl Drop for Dev {
    fn drop(&mut self) {
        unsafe { libevdev_free(self.raw) }
    }
}
