Describe 'api/characteristics GET'
  Before "export HOMEKIT_SH_LOGGING_LEVEL=debug"

  Before "export REQUEST_METHOD=GET"

  Describe 'non-existent'
    It 'returns failure status when characteristic does not exist'
      BeforeRun "export QUERY_STRING='id=-1.0'"
      When run ./api/characteristics
      The output should end with '{"characteristics":[{"aid":-1,"iid":0,"status":-70409}]}'
      The error should include "Characteristic 0 from accessory -1 not found!"
    End
  End



  Describe 'existing'
    It 'returns characteristic'
      BeforeRun "export QUERY_STRING='id=1.34'"
      When run ./api/characteristics
      The output should end with '{"characteristics":[{"aid":1,"iid":34,"value":"Homekit.sh"}]}'
      The error should include "Responding with ? 200"
    End
  End

  

  Describe 'multiple'
    It 'returns multiple characteristics'
      BeforeRun "export QUERY_STRING='id=1.1621055,1.34'"
      When run ./api/characteristics
      The output should include '{"aid":1,"iid":1621055,"value":"1.1.0"}'
      The output should include '{"aid":1,"iid":34,"value":"Homekit.sh"}'
      The error should include 'No "cmd" set in characteristic/service properties for 1.34 (AccessoryInformation.Model), returning given constant value'
    End
  End

End



Describe 'api/characteristics PUT'
  Before "export HOMEKIT_SH_LOGGING_LEVEL=debug"

  Before "export REQUEST_METHOD=PUT"
  Before "export REMOTE_ADDR=localhost"
  Before "export REMOTE_PORT=12345"

  Describe 'non-existent'
    It 'returns failure status when characteristic does not exist'
      Data
      #|{
      #| "characteristics": [
      #|   {"aid": -1, "iid": 0, "value": 42}
      #| ]
      #|}
      End
      When run ./api/characteristics
      The output should end with '{"characteristics":[{"aid":-1,"iid":0,"status":-70409}]}'
      The error should include "Characteristic 0 from accessory -1 not found!"
    End
  End

  Describe 'value'
    It 'returns failure status for readonly characteristic'
      Data
      #|{
      #| "characteristics": [
      #|   {"aid": 1, "iid": 33, "value": "foo"}
      #| ]
      #|}
      End
      When run ./api/characteristics
      The output should end with '{"characteristics":[{"aid":1,"iid":33,"status":-70404}]}'
      The error should include '"cmd" not set in characteristic/service properties'
    End
  End

End