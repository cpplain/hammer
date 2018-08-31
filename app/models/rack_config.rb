class RackConfig
  require 'csv'
  include Mongoid::Document
  include Mongoid::Timestamps
  field :sku, type: String
  embeds_one :elevation
  embeds_many :interfaces
  belongs_to :customer
  accepts_nested_attributes_for :elevation, :interfaces

  def self.field_keys
    RackConfig.fields.keys.drop(3)
  end

  def self.import(file, rack_config)
    CSV.foreach(file.path, headers: true) do |row|
      row_hash = row.to_hash

      elevation = update_elevation(row_hash, rack_config)
      update_rack_component(row_hash, elevation)
      update_connections(row_hash, rack_config)
    end
  end

  def self.update_elevation(row_hash, rack_config)
    # Grab elevation data and search for existing Elevation.
    elevation_hash = row_hash.slice(*Elevation.field_keys)
    elevation = rack_config.elevation
    rack = false
    rack = row_hash["rack"].downcase == "true" unless row_hash["rack"].nil?

    # Create new Elevation or update existing docuement.
    new_elevation_with_rack = elevation.nil? && rack
    new_elevation_without_rack = elevation.nil? && !rack

    if new_elevation_with_rack
      elevation = rack_config.create_elevation(elevation_hash)
    elsif new_elevation_without_rack
      elevation = rack_config.create_elevation()
    elsif rack
      elevation.update_attributes!(elevation_hash)
    end
    elevation
  end

  def self.update_rack_component(row_hash, elevation)
    # Grab rack component data and search for existing RackComponent.
    rack_component_hash = row_hash.slice(*RackComponent.field_keys)
    u_location = rack_component_hash["u_location"].to_i
    orientation = rack_component_hash["orientation"]
    part_number = row_hash["part_number"]
    rack_component = elevation.rack_components.where(
      u_location: u_location, orientation: orientation).first
    part = Part.where(part_number: part_number).first
    if part
      rack_component_hash[:part_id] = part.id
    else
      rack_component_hash[:part_id] = nil
    end

    # Create new RackComponent or update existing document.
    if rack_component.nil?
      rack_component = elevation.rack_components.create!(rack_component_hash)
    else
      rack_component.update_attributes!(rack_component_hash)
    end
    rack_component
  end

  def self.update_connections(row_hash, rack_config)
    (1..100).each do |n|
      # Grab interface data and search for existing Interface.
      interface_keys = Interface.field_keys.map { |key| key + n.to_s }
      interface_hash = row_hash.slice(*interface_keys).transform_keys { |key| key[/^([^\d])+/] }
      interface_group = interface_hash["interface_group"]
      interface = rack_config.interfaces.where(interface_group: interface_group).first

      # Create new Interface or update existing document.
      if interface.nil? && interface_group
        interface = rack_config.interfaces.create!(interface_hash)
      elsif interface_group
        interface.update_attributes!(interface_hash)
      else
        break
      end

      # Grab connection data and search for existing Connection.
      connection_keys = Connection.field_keys.map { |key| key + n.to_s }
      connection_hash = row_hash.slice(*connection_keys).transform_keys { |key| key[/^([^\d])+/] }
      local_port = connection_hash["local_port"]
      local_u = row_hash["u_location"]
      connection_hash[:local_u] = local_u
      connection_hash[:local_orientation] = row_hash["orientation"]
      connection = interface.connections.where(local_u: local_u, local_port: local_port).first

      # Create new Connection or update existing document.
      if connection.nil? && local_port
        interface.connections.create!(connection_hash)
      elsif local_port
        connection.update_attributes!(connection_hash)
      end
    end
  end
end
