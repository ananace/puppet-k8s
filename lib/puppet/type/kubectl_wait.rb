# frozen_string_literal: true

require 'puppet/parameter/boolean'

Puppet::Type.newtype(:kubectl_wait) do
  desc <<-DOC
  Example:

  To wait for the cluster DNS to be ready;

      kubectl_wait { "coredns":
        namespace   => 'kube-system',
        kubeconfig  => '/root/.kube/config',

        api_version => 'apps/v1,
        kind        => 'Deployment',

        condition   => 'Available',
      }
  DOC

  # XXX Better way to separate name from Puppet namevar handling?
  newparam(:resource_name) do
    desc 'The name of the resource'

    validate do |value|
      raise Puppet::Error, 'Resource name must be valid' unless value.match? %r{^([a-z0-9][a-z0-9.:-]{0,251}[a-z0-9]|[a-z0-9])$}
    end
  end

  newparam(:name, namevar: true) do
    desc 'The Puppet name of the instance'
  end

  newparam(:namespace) do
    desc 'The namespace the resource is contained in'

    validate do |value|
      raise Puppet::Error, 'Namespace must be valid' unless value.match? %r{^[a-z0-9.-]{0,253}$}
    end
  end

  newparam(:kubeconfig) do
    desc 'The kubeconfig file to use for handling the resource'

    validate do |value|
      raise Puppet::Error, 'Kubeconfig path must be fully qualified' unless Puppet::Util.absolute_path?(value)
    end
  end

  newparam(:api_version) do
    desc 'The apiVersion of the resource'

    defaultto('v1')
  end
  newparam(:kind) do
    desc 'The kind of the resource'
  end

  newparam(:timeout) do
    desc 'The duration to wait for, as a go duration - i.e. 1h30m20s (default 30s)'

    defaultto('30s')

    validate do |value|
      raise Puppet::Error, 'Not a valid go duration' unless value.is_a?(String) && %r{^(-?[0-9]+(\.[0-9]+)?(ns|us|µs|ms|s|m|h))+$}.match?(value)
    end
  end
  newparam(:refreshonly, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Should the wait only trigger on refresh'

    defaultto(:true)
  end

  newparam(:condition) do
    desc <<~DESC
      A resource condition to await

      Either a String or a Hash[String,Data,1,1]

      E.g.

      condition => 'Available'

      condition => {
        'Ready' => false,
      }
    DESC

    validate do |value|
      raise Puppet::Error, 'Condition must be either a string or single-entry hash' unless value.is_a?(String) || (value.is_a?(Hash) && value.size == 1)
    end
  end
  newparam(:delete, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Await resource deletion'

    validate do |value|
      raise Puppet::Error, 'Delete must be true' unless value == :true
    end
  end
  newparam(:json) do
    desc <<~DESC
      JSONPath expression to await

      Must be a String or Hash[String,Data,1,1]

      E.g.

      json => '.status.loadBalancer.ingress'

      json => {
        '.status.phase' => 'Running'
      }
    DESC

    validate do |value|
      raise Puppet::Error, 'JSON must be either a string or single-entry hash' unless value.is_a?(String) || (value.is_a?(Hash) && value.size == 1)
    end
  end

  newproperty(:awaited, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Placeholder to trigger wait'

    defaultto(:true)

    def retrieve
      if self[:refreshonly] == :true
        should
      else
        :not_awaited
      end
    end

    def sync
      provider.run
    end
  end

  validate do
    self[:resource_name] = self[:name] if self[:resource_name].nil?

    raise Puppet::Error, 'API version is required' unless self[:api_version]
    raise Puppet::Error, 'Kind is required' unless self[:kind]
    puts "Calling wait with conditions: #{[self[:condition], self[:delete], self[:json]].compact.inspect}"
    raise Puppet::Error, 'One - and only one - of condition/delete/json must be specified' unless [self[:condition], self[:delete], self[:json]].compact.size == 1

  end

  def refresh
    property(:awaited).sync
  end

  autorequire(:kubeconfig) do
    [self[:kubeconfig]]
  end
  autorequire(:service) do
    ['kube-apiserver']
  end
  autorequire(:exec) do
    ['k8s apiserver wait online']
  end
  autorequire(:file) do
    [
      self[:kubeconfig],
    ]
  end
  autorequire(:k8s__binary) do
    ['kubectl']
  end

  def nice_name
    return self[:name] unless self[:namespace]

    "#{self[:namespace]}/#{self[:name]}"
  end
end

