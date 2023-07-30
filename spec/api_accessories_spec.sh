Describe 'api/accessories'

  Describe 'GET'
    It 'returns accessories'
      When run ./api/accessories
      The output should start with "HTTP/1.1 200 OK"
      The error should eq "Responding with 200"
    End
  End

End