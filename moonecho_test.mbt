///|
test "project identity" {
  assert_eq(@moonecho.project_name(), "MoonEcho")
  assert_eq(@moonecho.project_name_zh(), "月响")
  assert_eq(@moonecho.project_version(), "0.1.1")
}

///|
test "status is human-readable" {
  assert_true(@moonecho.status().contains("MoonEcho"))
  assert_true(@moonecho.status().contains("0.1.1"))
  assert_true(@moonecho.status().contains("fingerprint"))
}
