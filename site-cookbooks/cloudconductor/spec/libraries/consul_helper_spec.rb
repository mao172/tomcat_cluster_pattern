require_relative '../spec_helper'
require_relative '../../libraries/consul_helper'

describe CloudConductor::ConsulClient do
  describe '::Catalog #service' do
    before do
      @helper = CloudConductor::ConsulClient
    end

    it 'return services hash of the passed id' do
      response_body = ['[{"Node":"consul1","Address":"172.17.0.49","ServiceID":"db",',
                       '"ServiceName":"db","ServiceTags":null,"ServicePort":5432}]'].join
      response = Faraday::Response
      allow(response).to receive(:body).and_return(response_body)

      allow(@helper).to receive_message_chain(:http, :get).with(:no_args).with('catalog/service/db').and_return(response)
      expect(@helper::Catalog.service('db')).to eq(JSON.parse(response_body))
    end

    it 'return services hash of the passed id and filters (tag)' do
      response_body_by_tag = ['[{"Node":"consul1","Address":"172.17.0.49","ServiceID":"db",',
                              '"ServiceName":"db","ServiceTags":"db","ServicePort":5432}]'].join
      response_by_tag = Faraday::Response
      allow(response_by_tag).to receive(:body).and_return(response_body_by_tag)

      allow(@helper).to receive_message_chain(:http, :get).with(:no_args).with('catalog/service/db?tag=value').and_return(response_by_tag)
      expect(@helper::Catalog.service('db', 'tag' => 'value')).to eq(JSON.parse(response_body_by_tag))
    end

    it 'return services hash of the passed id and filters (dc)' do
      response_body_by_dc = ['[{"Node":"consul1","Address":"172.17.0.49","ServiceID":"db",',
                             '"ServiceName":"db","ServiceTags":null,"ServicePort":5432,"DC":"DC1"}]'].join
      response_by_dc = Faraday::Response
      allow(response_by_dc).to receive(:body).and_return(response_body_by_dc)

      allow(@helper).to receive_message_chain(:http, :get).with(:no_args).with('catalog/service/db?dc=value').and_return(response_by_dc)
      expect(@helper::Catalog.service('db', 'dc' => 'value')).to eq(JSON.parse(response_body_by_dc))
    end

    it 'return services hash of the passed id and filters (tag & dc)' do
      response_body_by_tag_and_dc = ['[{"Node":"consul1","Address":"172.17.0.49","ServiceID":"db",',
                                     '"ServiceName":"db","ServiceTags":"db","ServicePort":5432, "DC":"DC1"}]'].join
      response_by_tag_and_dc = Faraday::Response
      allow(response_by_tag_and_dc).to receive(:body).and_return(response_body_by_tag_and_dc)

      allow(@helper).to receive_message_chain(:http, :get).with(:no_args).with('catalog/service/db?tag=value&dc=value').and_return(response_by_tag_and_dc)
      expect(@helper::Catalog.service('db', 'tag' => 'value', 'dc' => 'value')).to eq(JSON.parse(response_body_by_tag_and_dc))
    end

    it 'filter ignored other than dc and tag' do
      response_body = ['[{"Node":"consul1","Address":"172.17.0.49","ServiceID":"db",',
                       '"ServiceName":"db","ServiceTags":null,"ServicePort":5432}]'].join
      response = Faraday::Response
      allow(response).to receive(:body).and_return(response_body)

      allow(@helper).to receive_message_chain(:http, :get).with(:no_args).with('catalog/service/db').and_return(response)
      expect(@helper::Catalog.service('db', 'fake' => 'value')).to eq(JSON.parse(response_body))
    end
  end

  describe '#client' do
    before do
      @helper = CloudConductor::ConsulClient
    end

    it 'return faraday connection to the local consul api v1' do
      expect(@helper.send(:http).url_prefix.to_s).to eq('http://localhost:8500/v1')
    end
  end
end
