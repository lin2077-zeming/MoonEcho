///|
fn main {
  try @cli.run(@env.args()) catch {
    err => {
      println("moonecho: \{@cli.error_message(err)}")
      @sys.exit(1)
    }
  } noraise {
    output => println(output)
  }
}
