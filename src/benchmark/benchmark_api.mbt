///|
pub fn error_message(error : BenchmarkError) -> String {
  match error {
    Build(message) => message
  }
}
