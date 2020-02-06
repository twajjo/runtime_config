# List all modules that can be mocked in a test.  All modules MUST have ".API" module defined.
# .Mock modules will be created for each module listed below but must also be listed in config/test.exs
modules_to_mock = [
    Runtime.Config.Helper.Wrapper
]

for module <- modules_to_mock do
  Code.ensure_compiled?(module)
  Code.ensure_compiled?(Module.concat(module, API))

  module
  |> Module.concat(Mock)
  |> Mox.defmock(for: Module.concat(module, API))
end