require_relative '../spec_helper'

describe 'tomcat_part::default' do
  let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  before do
    stub_command("grep \"org.apache.catalina.STRICT_SERVLET_COMPLIANCE\" /usr/share/tomcat7/conf/catalina.properties\n").and_return(false)
    chef_run.converge(described_recipe)
  end

  it 'include setup recipe' do
    expect(chef_run).to include_recipe('tomcat_part::setup')
  end
end
