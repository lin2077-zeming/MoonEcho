///|
fn main {
  println(@cli.run(@env.args())) catch {
    err => println("moonecho: \{@cli.error_message(err)}")
  }
}
