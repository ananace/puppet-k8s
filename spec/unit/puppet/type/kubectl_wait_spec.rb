# frozen_string_literal: true

require 'spec_helper'
require 'puppet'

describe Puppet::Type.type(:kubectl_wait) do
  let(:resource) do
    Puppet::Type.type(:kubectl_wait).new(
      name: 'coredns',
      namespace: 'kube-system',

      api_version: 'apps/v1',
      kind: 'Deployment',

      condition: 'Available'
    )
  end

  context 'resource defaults' do
    it { expect(resource[:kubeconfig]).to be_nil }
    it { expect(resource[:refreshonly]).to be true }
  end

  %w[
    simplename
    default-token-6mqpl
    metrics-server-7cb45bbfd5-gz4t6
  ].each do |name|
    it 'accepts valid names' do
      expect { resource[:resource_name] = name }.not_to raise_error
    end
  end

  [
    'CamelCasedName',
    'name-with space',
    'snake_cased_name',
    'fqdn.like/name',
  ].each do |name|
    it 'rejects invalid names' do
      expect { resource[:resource_name] = name }.to raise_error(Puppet::ResourceError, %r{Resource name must be valid})
    end
  end

  %w[
    default
    kube-system
    some-ridiculously-long-name-thats-still-inside-of-the-limitations-kubernetes-has
  ].each do |name|
    it 'accepts valid namespaces' do
      expect { resource[:namespace] = name }.not_to raise_error
    end
  end

  [
    'CamelCasedName',
    'name-with space',
    'snake_cased_name',
    'fqdn.like/name',
  ].each do |name|
    it 'rejects invalid namespaces' do
      expect { resource[:namespace] = name }.to raise_error(Puppet::Error, %r{Namespace must be valid})
    end
  end

  it 'rejects too long namespaces' do
    expect { resource[:namespace] = 'x' * 254 }.to raise_error(Puppet::Error, %r{Namespace must be valid})
  end

  it 'verify resource[:kubeconfig] is absolute filepath' do
    expect { resource[:kubeconfig] = 'relative/file' }.to raise_error(Puppet::Error, %r{Kubeconfig path must be fully qualified})
  end

  [
    '300ms',
    '-1.5h',
    '2h45m',
    '1h10m10s',
    '1µs',
    '1us',
  ].each do |value|
    it 'accepts valid tiemouts' do
      expect { resource[:timeout] = value }.not_to raise_error
    end
  end

  [
    [nil],
    [nil, nil],
    { 'foo' => 'bar' },
    {},
    '',
    's',
    '.5s',
    'blah',
    '199',
    600,
    1_000,
  ].each do |value|
    it 'rejects invalid timeouts' do
      expect { resource[:timeout] = value }.to raise_error(Puppet::Error, %r{Not a valid go duration})
    end
  end

  it 'verify resource[:condition] is a string or single-element hash' do
    expect { resource[:condition] = [] }.to raise_error(Puppet::Error, %r{Condition must be})
    expect { resource[:condition] = 5 }.to raise_error(Puppet::Error, %r{Condition must be})
    expect { resource[:condition] = { a: 1, b: 2 } }.to raise_error(Puppet::Error, %r{Condition must be})
    expect { resource[:condition] = 'Ready' }.not_to raise_error
    expect { resource[:condition] = { 'Ready' => false } }.not_to raise_error
  end

  it 'verify resource[:delete] is the boolean true' do
    expect { resource[:delete] = [] }.to raise_error(Puppet::Error, %r{Delete must be})
    expect { resource[:delete] = false }.to raise_error(Puppet::Error, %r{Delete must be})
    expect { resource[:delete] = :false }.to raise_error(Puppet::Error, %r{Delete must be})
    expect { resource[:delete] = :true }.not_to raise_error
  end

  it 'verify resource[:json] is a string or single-element hash' do
    expect { resource[:json] = [] }.to raise_error(Puppet::Error, %r{JSON must be})
    expect { resource[:json] = 5 }.to raise_error(Puppet::Error, %r{JSON must be})
    expect { resource[:json] = { a: 1, b: 2 } }.to raise_error(Puppet::Error, %r{JSON must be})
    expect { resource[:json] = '.status.loadBalancer.ingress' }.not_to raise_error
    expect { resource[:json] = { '.status.phase' => 'Running' } }.not_to raise_error
  end

  describe 'file autorequire' do
    let(:file_resource) { Puppet::Type.type(:file).new(name: '/root/.kube/config') }
    let(:kubectl_wait_resource) do
      described_class.new(
        name: 'blah',
        namespace: 'default',
        api_version: 'v1',
        kind: 'ConfigMap',
        kubeconfig: '/root/.kube/config',
        condition: 'Available'
      )
    end

    let(:auto_req) do
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource file_resource
      catalog.add_resource kubectl_wait_resource

      kubectl_wait_resource.autorequire
    end

    it 'creates relationship' do
      expect(auto_req.size).to be 1
    end

    it 'links to file resource' do
      expect(auto_req[0].target).to eql kubectl_wait_resource
    end
  end
end
