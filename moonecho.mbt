///|
/// Public project name used by the CLI, documentation, and generated reports.
pub fn project_name() -> String {
  @project.project_name()
}

///|
/// Chinese project name.
pub fn project_name_zh() -> String {
  @project.project_name_zh()
}

///|
/// Current project version. Keep this in sync with `moon.mod`.
pub fn project_version() -> String {
  @project.project_version()
}

///|
/// Short description of the project goal.
pub fn project_summary() -> String {
  @project.project_summary()
}

///|
/// Human-readable status line for the first runnable skeleton.
pub fn status() -> String {
  @project.status()
}
