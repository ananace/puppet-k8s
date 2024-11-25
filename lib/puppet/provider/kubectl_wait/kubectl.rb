# frozen_string_literal: true

require File.expand_path('../../util/k8s', __dir__)

# Applies resources as data in a Kubernetes cluster
Puppet::Type.type(:kubectl_wait).provide(:kubectl) do
  commands kubectl: 'kubectl'

  def run
    kubectl_wait
  end

  private

  def wait_for
    if resource[:delete]
      ['--for', 'delete']
    elsif resource[:condition]
      case resource[:condition]
      when String
        ['--for', ['condition', resource[:condition]].join('=')]
      when Hash
        ['--for', ['condition', resource[:condition].keys.first, resource[:condition].values.first].join('=')]
      end
    elsif resource[:json]
      case resource[:json]
      when String
        ['--for', ['jsonpath', "'{#{resource[:json].keys.first}}'"].join('=')]
      when Hash
        ['--for', ['jsonpath', ["'{#{resource[:json].keys.first}}'", resource[:json].values.first].join('=')]]
      end
    end
  end

  def wait_timeout
    ['--timeout', resource[:timeout] || '30s']
  end

  def resource_kind
    if resource[:api_version].include? '/'
      group, version = resource[:api_version].split('/')
      [resource[:kind], version, group].join('.')
    else
      resource[:kind]
    end
  end

  def kubectl_wait
    kubectl_cmd 'wait', resource_kind, resource[:resource_name], *wait_timeout, *wait_for
  rescue StandardError => e
    raise Puppet::Error, "#{e.class}: #{e}"
  end

  def kubectl_cmd(*args)
    params = []
    if resource[:namespace]
      params << '--namespace'
      params << resource[:namespace]
    end
    if resource[:kubeconfig]
      params << '--kubeconfig'
      params << resource[:kubeconfig]
    end

    kubectl(*params, *args)
  end
end
