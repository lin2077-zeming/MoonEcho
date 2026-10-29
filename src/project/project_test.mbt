///|
test "project identity" {
  assert_eq(@project.project_name(), "MoonEcho")
  assert_eq(@project.project_name_zh(), "月响")
  assert_eq(@project.project_version(), "0.1.4")
}

///|
test "status is human-readable" {
  assert_true(@project.status().contains("MoonEcho"))
  assert_true(@project.status().contains("0.1.4"))
  assert_true(@project.status().contains("fingerprint"))
}
