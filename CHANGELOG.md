druid CHANGELOG
===============

0.0.2
-----
- [cjmateos]
  - 4ae0937 Merge pull request from redBorder/improvement/wrapper_support
  - b20a6d9 Delete unused scripts
  - e515d91 Adapt scripts to wrapper
  - 7792714 Adaption of spec for wrapping ruby scripts
  - 693945d Update version

0.0.1
-----
- 30a86f5 Add doc
- e0d210e Avoid send empty certificates
- 332dee2 Fix typo in resources/01default_handlers.json
- a773679 Replaced chef check for consul check using serf members
- b75b4f8 Add systemd dependecity with network start
- 0071ce8 Permit only chef and full mode to leader
- 5ef6a34 Delete ip leader when choose-custom is executed
- 920dac7 Fix in serf-choose-leader.sh
- 7af8eef Remove check for query result
- 5b946cd Checking if leader is ready before execute configure_custom
- 440bdb5 Send chef server location to configure custom script
- e9a9811 Remove CR in serf-chef-server-location return
- dcd0ed1 Protect serf-send-certificate to avoid to send invalid responses
- 6333861 Fix in serf-chef-server-location.sh
- 9c359da Fix bug when query results with various responses
- 92fb2cf Use absolute path in queries
- 554292b Support to obtain chef location in leader election and changed tag from master to leader
- b4a7bb6 Fix typo in serf-join unit file
- 26f5db4 Use tag mode
- 6f5a507 Change unit file to run serf. serf-agent scripts are deprecated
- 07b97d6 added support to other certificates
- 52d622d fixed unit file for serf-join
- 3756757 Fix bug with tags
- b0ca4a3 Fix script name
- 6795370 Added configuration post-scripts
- eaacfec Fix problem with config file in spec
- 0e2ab45 Added default event handlers
- f9c0644 Renamed scripts
- aa695d1 changed master tag from yes to inprogress
- f39b99c Deleted unnecessary file
- f682121 Added query certificate script to obtain RSA certificate for managers
- 65841d7 added query script to send certificate
- 5432852 Added post script installation to reload systemd
- 0a3b66e Fix unit file
- 444322f Added jq dependency
- 8362a9f Added new systemd unit file for serf-join service to spec
- 4a420a9 Added dependencies between serf and serf-join services
- 10dd364 Added new service to join to cluster
