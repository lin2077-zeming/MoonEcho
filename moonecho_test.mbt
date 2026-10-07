///|
test "project identity" {
  assert_eq(@moonecho.project_name(), "MoonEcho")
  assert_eq(@moonecho.project_name_zh(), "月响")
  assert_eq(@moonecho.project_version(), "0.1.0")
}

///|
test "status is human-readable" {
  assert_true(@moonecho.status().contains("MoonEcho"))
  assert_true(@moonecho.status().contains("0.1.0"))
  assert_true(@moonecho.status().contains("fingerprint"))
}
