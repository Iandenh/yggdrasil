require 'ffi'
require 'json'

TOGGLE_MISSING_RESPONSE = 'NotFound'.freeze
ERROR_RESPONSE = 'Error'.freeze
OK_RESPONSE = 'Ok'.freeze

def platform_specific_lib
  case RbConfig::CONFIG['host_os']
  when /darwin|mac os/
    'libyggdrasilffi.dylib'
  when /linux/
    'libyggdrasilffi.so'
  when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
    'libyggdrasilffi.dll'
  else
    raise "unsupported platform #{RbConfig::CONFIG['host_os']}"
  end
end

class Variant
  attr_accessor :enabled, :name, :payload

  def initialize(attributes = {})
    self.enabled = attributes['enabled'] || false
    self.name = attributes['name'] || 'disabled'
    self.payload = attributes['payload']
  end

  def to_s
    "Variant: #{self.name} enabled: #{self.enabled} payload: #{self.payload}"
  end
end

class UnleashEngine
  extend FFI::Library
  ffi_lib File.expand_path(platform_specific_lib, __dir__)

  attach_function :engine_new, [], :pointer
  attach_function :engine_free, [:pointer], :void

  attach_function :engine_take_state, %i[pointer string], :pointer
  attach_function :engine_check_enabled, %i[pointer string string], :pointer
  attach_function :engine_check_variant, %i[pointer string string], :pointer
  attach_function :engine_get_metrics, [:pointer], :pointer
  attach_function :engine_free_response_message, [:pointer], :void

  attach_function :engine_count_toggle, %i[pointer string bool], :void
  attach_function :engine_count_variant, %i[pointer string string], :void

  def initialize
    @engine_state = UnleashEngine.engine_new
    ObjectSpace.define_finalizer(self, self.class.finalize(@engine_state))
  end

  def self.finalize(engine_state)
    proc { UnleashEngine.engine_free(engine_state) }
  end

  def take_state(toggles)
    response_ptr = UnleashEngine.engine_take_state(@engine_state, toggles)
    take_toggles_response = JSON.parse(response_ptr.read_string, symbolize_names: true)
    UnleashEngine.engine_free_response_message(response_ptr)
  end

  def get_variant(name, context)
    context_json = (context || {}).to_json

    variant_def_json_ptr = UnleashEngine.engine_check_variant(@engine_state, name, context_json)
    variant_def_json = variant_def_json_ptr.read_string
    UnleashEngine.engine_free_response_message(variant_def_json_ptr)
    variant_response = JSON.parse(variant_def_json, symbolize_names: true)

    return nil if variant_response[:status_code] == TOGGLE_MISSING_RESPONSE
    return variant_response[:value] if variant_response[:status_code] == OK_RESPONSE
  end

  def enabled?(toggle_name, context)
    context_json = (context || {}).to_json

    response_ptr = UnleashEngine.engine_check_enabled(@engine_state, toggle_name, context_json)
    response_json = response_ptr.read_string
    UnleashEngine.engine_free_response_message(response_ptr)
    response = JSON.parse(response_json, symbolize_names: true)

    raise "Error: #{response[:error_message]}" if response[:status_code] == ERROR_RESPONSE
    return nil if response[:status_code] == TOGGLE_MISSING_RESPONSE
    return response[:value] == true
  end

  def count_toggle(toggle_name, enabled)
    UnleashEngine.engine_count_toggle(@engine_state, toggle_name, enabled)
  end

  def count_variant(toggle_name, variant_name)
    UnleashEngine.engine_count_variant(@engine_state, toggle_name, variant_name)
  end

  def get_metrics
    metrics_ptr = UnleashEngine.engine_get_metrics(@engine_state)
    metrics = JSON.parse(metrics_ptr.read_string, symbolize_names: true)
    UnleashEngine.engine_free_response_message(metrics_ptr)
    metrics[:value]
  end
end