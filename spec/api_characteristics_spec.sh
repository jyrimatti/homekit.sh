Describe 'api/characteristics GET'
  Before "export REQUEST_METHOD=GET"

  Describe 'non-existent'
    It 'returns failure status when characteristic does not exist'
      result() { cat << EOF
HTTP/1.1 207 Multi-Status
Content-Type: application/hap+json
Content-Length: 99

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
      error() { cat << EOF
Characteristic 0 from accessory -1 not found!
Responding with 207
EOF
      }
      BeforeRun "export QUERY_STRING='id=-1.0'"
      When run ./api/characteristics
      The output should eq "$(result)"
      The error should eq "$(error)"
    End
  End



  Describe 'existing'
    It 'returns characteristic'
      result() { cat << EOF
HTTP/1.1 200 OK
Content-Type: application/hap+json
Content-Length: 104

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
      The error should eq "Responding with 200"
    End
  End

  

  Describe 'multiple'
    It 'returns multiple characteristics'
      result() { cat << EOF
HTTP/1.1 200 OK
Content-Type: application/hap+json
Content-Length: 182

{
  "characteristics": [
    {
      "aid": 1829683084,
      "iid": 1450035,
      "value": 42
    },
    {
      "aid": 1,
      "iid": 34,
      "value": "Homekit.sh"
    }
  ]
}
EOF
      }
      BeforeRun "export QUERY_STRING='id=1829683084.1450035,1.34'"
      When run ./api/characteristics
      The output should eq "$(result)"
      The error should start with "stiebel/fektemp.sh Get:"
    End
  End

End



Describe 'api/characteristics PUT'
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
HTTP/1.1 207 Multi-Status
Content-Type: application/hap+json
Content-Length: 99

{
  "characteristics": [
    {
      "aid": -1,
      "iid": 0,
      "status": -70404
    }
  ]
}
EOF
      }
      error() { cat << EOF
Characteristic 0 from accessory -1 not found!
'cmd' not set in service properties!
Responding with 207
EOF
      }
      When run ./api/characteristics
      The output should eq "$(result)"
      The error should eq "$(error)"
    End
  End

  Describe 'value'
    It 'returns OK'
      Data
      #|{
      #| "characteristics": [
      #|   {"aid": 1829683084, "iid": 33, "value": "foo"}
      #| ]
      #|}
      End
      result() { cat << EOF
HTTP/1.1 207 Multi-Status
Content-Type: application/hap+json
Content-Length: 108

{
  "characteristics": [
    {
      "aid": 1829683084,
      "iid": 33,
      "status": -70404
    }
  ]
}
EOF
      }
      error() { cat << EOF
'cmd' not set in service properties!
Responding with 207
EOF
      }
      When run ./api/characteristics
      The output should eq "$(result)"
      The error should eq "$(error)"
    End
  End

End