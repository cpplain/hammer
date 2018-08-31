class RackComponent
  include Mongoid::Document
  include Mongoid::Timestamps
  field :u_location, type: Integer
  field :orientation, type: String
  field :u_size, type: Integer
  field :sku, type: String
  field :part_id, type: BSON::ObjectId
  embedded_in :elevation

  def part
    Part.find(self.part_id) if self.part_id
  end

  def self.field_keys
    RackComponent.fields.keys.drop(3)
  end
end
