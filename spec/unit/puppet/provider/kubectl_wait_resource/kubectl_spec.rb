# frozen_string_literal: true

require 'spec_helper'

kubectl_provider = Puppet::Type.type(:kubectl_wait).provider(:kubectl)

RSpec.describe kubectl_provider do
  describe 'kubectl provider' do
    include PuppetlabsSpec::Files
    let(:tmpfile) do
      tmpfilename('kubeconfig_test')
    end

    let(:name) { 'coredns' }
    let(:resource_properties) do
      {
        name: name,
        namespace: 'kube-system',

        api_version: 'apps/v1',
        kind: 'Deployment',

        condition: 'Available'
      }
    end

    let(:kubectl_params) do
      [
        '--namespace',
        'kube-system',
        'wait',
        'Deployment.v1.apps',
        name,
        '--timeout',
        '30s',
        '--for',
        'condition=Available'
      ]
    end

    let(:resource) { Puppet::Type::Kubectl_wait.new(resource_properties) }
    let(:provider) { kubectl_provider.new(resource) }

    before do
      resource.provider = provider

      allow(kubectl_provider).to receive(:suitable?).and_return(true)
    end

    it 'runs a correct wait command' do
      expect(provider).to receive(:kubectl).with(*kubectl_params)

      provider.run
    end
  end
end
