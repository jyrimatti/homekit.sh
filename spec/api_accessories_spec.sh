Describe 'api/accessories'
  Before "export LOGGING_LEVEL=debug"

  Describe 'GET'
    It 'returns accessories'
      When run ./api/accessories
      The output should start with "Content-Type: application/hap+json"
      The error should end with "Responding with ? 200"
    End
  End

End