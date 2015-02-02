require_relative '../spec_helper'
require_relative '../../libraries/helper'

describe CloudConductor::Helper do
  describe '#generate_password' do
    before do
      @helper = Object.new
      @helper.extend CloudConductor::Helper
    end

    it 'return generate_password string that length is 64 characters' do
      node = { 'cloudconductor' => { 'salt' => 'db310da43d290e5dd54e5e2c5926385c' } }
      allow(@helper).to receive(:node).and_return(node)
      expect(@helper.generate_password).to match(/[0-9a-f]{64}/)
    end

    it 'return random string that generated by salt' do
      node = { 'cloudconductor' => { 'salt' => 'db310da43d290e5dd54e5e2c5926385c' } }
      allow(@helper).to receive(:node).and_return(node)
      expect(@helper.generate_password).to eq('4d6240ace778fbf59ef9784869d54b40282a323adb7b762fb4e7ee7e1b93c0df')
    end

    it 'return same random string if passed same keys' do
      node = { 'cloudconductor' => { 'salt' => 'db310da43d290e5dd54e5e2c5926385c' } }
      allow(@helper).to receive(:node).and_return(node)
      random1 = @helper.generate_password('key')
      random2 = @helper.generate_password('key')

      expect(random1).to eq(random2)
    end

    it 'return different random string if passed different keys' do
      node = { 'cloudconductor' => { 'salt' => 'db310da43d290e5dd54e5e2c5926385c' } }
      allow(@helper).to receive(:node).and_return(node)
      random1 = @helper.generate_password('key1')
      random2 = @helper.generate_password('key2')

      expect(random1).not_to eq(random2)
    end
  end
end
