Describe 'api/characteristics GET'
  Before "export LOGGING_LEVEL=debug"

  Before "export REQUEST_METHOD=GET"

  Describe 'non-existent'
    It 'returns failure status when characteristic does not exist'
      result() { cat << EOF
Content-Type: application/hap+json
Content-Length: 98

{
  "characteristics": [
    {
      "aid": -1,
      "iid": 0,
      "status": -70409
    }
  ]
}
EOF
      }
      BeforeRun "export QUERY_STRING='id=-1.0'"
      When run ./api/characteristics
      The output should eq "$(result)"
      The error should include "Characteristic 0 from accessory -1 not found!"
    End
  End



  Describe 'existing'
    It 'returns characteristic'
      result() { cat << EOF
Content-Type: application/hap+json
Content-Length: 103

{
  "characteristics": [
    {
      "aid": 1,
      "iid": 34,
      "value": "Homekit.sh"
    }
  ]
}
EOF
      }
      BeforeRun "export QUERY_STRING='id=1.34'"
      When run ./api/characteristics
      The output should eq "$(result)"
      The error should end with "Responding with ? 200"
    End
  End

  

  Describe 'multiple'
    It 'returns multiple characteristics'
      result1() { cat << EOF
    {
      "aid": 1,
      "iid": 2741055,
      "value": "1.1.0"
    }
EOF
      }
      result2() { cat << EOF
    {
      "aid": 1,
      "iid": 34,
      "value": "Homekit.sh"
    }
EOF
      }
      BeforeRun "export QUERY_STRING='id=1.2741055,1.34'"
      When run ./api/characteristics
      The output should include "$(result1)"
      The output should include "$(result2)"
      The error should include '"cmd" not set in characteristic/service properties -> take the constant defined in configuration'
    End
  End

End



Describe 'api/characteristics PUT'
  Before "export LOGGING_LEVEL=debug"

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
      result() { cat << EOF
Content-Type: application/hap+json
Content-Length: 98

{
  "characteristics": [
    {
      "aid": -1,
      "iid": 0,
      "status": -70409
    }
  ]
}
EOF
      }
      When run ./api/characteristics
      The output should eq "$(result)"
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
      result() { cat << EOF
Content-Type: application/hap+json
Content-Length: 98

{
  "characteristics": [
    {
      "aid": 1,
      "iid": 33,
      "status": -70404
    }
  ]
}
EOF
      }
      When run ./api/characteristics
      The output should eq "$(result)"
      The error should include '"cmd" not set in characteristic/service properties'
    End
  End

End