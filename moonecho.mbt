///|
/// Public project name used by the CLI, documentation, and generated reports.
pub fn project_name() -> String {
  "MoonEcho"
}

///|
/// Chinese project name.
pub fn project_name_zh() -> String {
  "月响"
}

///|
/// Current project version. Keep this in sync with `moon.mod`.
pub fn project_version() -> String {
  "0.1.0"
}

///|
/// Short description of the project goal.
pub fn project_summary() -> String {
  "Local-first acoustic fingerprint search and audio alignment toolkit"
}

///|
/// Human-readable status line for the first runnable skeleton.
pub fn status() -> String {
  "\{project_name()} (\{project_name_zh()}) v\{project_version()}: \{project_summary()}"
}
