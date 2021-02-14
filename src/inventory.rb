# Module: Inventory

# Fields should match database
class Item
  # Construct a new item.
  def initialize(hash)
    @entry_id = hash[:entry_id]
    @owner_user_id = hash[:owner_user_id]
    @item_id = hash[:item_id]
    @timestamp = hash[:timestamp]
    @expiration = hash[:expiration]
    @value = hash[:value]
  end

  # Get entry id
  def entry_id
    return @entry_id
  end

  # Get owner user id
  def owner_user_id
    return @owner_user_id
  end

  # Get item id
  def item_id
    return @item_id
  end

  # Get timestamp
  def timestamp
    return @timestamp
  end

  # Get expiration timestamp
  def expiration
    return @expiration
  end

  # Get value
  def value
    return @value
  end

  # Get item type
  def item_type
    return Bot::Inventory::GetItemTypeFromID(@item_id)
  end

  # Get ui name
  def ui_name
    Bot::Inventory::GetItemUINameFromID(@item_id)
  end
end

# Helper functions for inventory management
# Note: Not defined in lib because DB must already be init'ed.
module Bot::Inventory
  include Constants
  include Convenience

  # User inventory (purchased/received items)
  # { entry_id, owner_user_id, item_id, timestamp, expiration, value }
  USER_INVENTORY = DB[:econ_user_inventory]

  # Path to economy data folder
  ECON_DATA_PATH = "#{Bot::DATA_PATH}/economy".freeze

  module_function

  # Get the catalogue yaml document.
  # @return [YAML] Yaml catalogue document.
  def GetCatalogue()
    return YAML.load_data!("#{ECON_DATA_PATH}/catalogue.yml")
  end

  # Get a generic value from the catalogue.
  # @param [Generic] key
  # @return [Generic] value or nil if not found.
  def GetValueFromCatalogue(key)
    return GetCatalogue()[key]
  end

  # Get the item's unique id from the name.
  # @param [String] item_name Item's name as specified in catalogue.yaml
  # @return [Integer] Item id. Nil if not found.
  def GetItemID(item_name)
    item_id_name = item_name + "_id"
    return GetCatalogue()[item_id_name]
  end
  
  # Get the item's unique id from the name.
  # @param [Integer] item_id The item's unique id.
  # @return [Integer] item type id
  def GetItemTypeFromID(item_id)
    return item_id & 0xF000
  end

  # Get the item's unique id from the name.
  # @param [String] item_name Item's name as specified in catalogue.yaml
  # @return [Integer] item type id
  def GetItemType(item_name)
    item_id = GetItemID(item_name)
    return GetItemTypeFromID(item_id)
  end

  # Get the value of a type of item.
  # @param [Integer] item_type_id item type identifier.
  # @return [Integer] The value of the item type in Starbucks. Returns zero if not found.
  def GetItemTypeValue(item_type)
    point_value_key = GetCatalogue()[item_type]
    return 0 if point_value_key == nil
    return Bot::Bank::AppraiseItem(point_value_key)
  end

  # Get an item's value from the id.
  # @param [Integer] item_id item id
  # @return [Integer] The value of the item in Starbucks.
  def GetItemValueFromID(item_id)
    item_type = GetItemTypeFromID(item_id)
    return GetItemTypeValue(item_type)
  end

  # Get an item's value from the id.
  # @param [Integer] item_id item id
  # @return [Integer] The value of the item in Starbucks.
  def GetItemValue(item_name)
    item_type = GetItemType(item_name)
    return GetItemTypeValue(item_type)
  end

  # Get an item's ui name from a the id.
  # @param [Integer] item_id item id
  # @return [String] item name or nil if not found 
  def GetItemUINameFromID(item_id)
    return GetCatalogue()[item_id]
  end

  # Get an item's ui name from a the code name.
  # @param [Integer] item_name item name
  # @return [String] item name or nil if not found 
  def GetItemUINameFromName(item_name)
    item_id = GetItemID(item_name)
    return GetCatalogue()[item_id]
  end

  # Add an item to the user's inventory.
  # @param [Integer] user_id    user id
  # @param [Integer]  item_id   item id
  # @param [Integer] expiration when the item expires
  # @return [bool] Success?
  def AddItem(user_id, item_id, expiration = nil)
    owner_user_id = user_id
    timestamp = Time.now.to_i
    value = GetItemValueFromID(item_id)

    # add item
    USER_INVENTORY << { owner_user_id: owner_user_id, item_id: item_id, timestamp: timestamp, expiration: expiration, value: value }
    return true
  end
  
  # Add an item to the user's inventory by name.
  # @param [Integer] user_id    user id
  # @param [String]  item_name  name of the item in catalogue.yml
  # @param [Integer] expiration when the item expires
  # @return [bool] Success?
  def AddItemByName(user_id, item_name, expiration = nil)
    # aggregate item information
    item_id = GetItemID(item_name)
    if item_id == nil
      raise ArgumentError, "Invalid item name specified #{item_name}!"
      return false
    end

    return AddItem(user_id, item_id, expiration)
  end

  # Remove the specified item from inventory.
  # @param [Integer] remove the specified item.
  # @return [bool] Success?
  def RemoveItem(entry_id)
    USER_INVENTORY.where(entry_id: entry_id).delete
    return true
  end

  # Get the user's complete inventory
  # @param [Integer] user_id   user id
  # @param [Integer] item_type optional: item type to filter by
  # @return [Array<Item>] items the user has.
  def GetInventory(user_id, item_type = nil)
    items = USER_INVENTORY.where(owner_user_id: user_id)
    if item_type != nil
      items = items.where{Sequel.&((item_id >= item_type), (item_id < item_type + 0x1000))}
    end

    items = items.all
    inventory = []
    
    items.each do |item|
      inventory.push(Item.new(item))
    end

    return inventory
  end

  # Get the value of the user's entire inventory.
  # @param [Integer] user_id user id
  # @return [Integer] total value
  def GetInventoryValue(user_id)
    return USER_INVENTORY.where(owner_user_id: user_id).sum(:value)
  end

  # Get list of users that have an inventory.
  # @return [Array<Integer>] Array of user ids.
  #
  # Note: Easy way to iterate over all user's inventories.
  def GetUsersWithInventory()
    users = DB["SELECT DISTINCT owner_user_id FROM econ_user_inventory"]

    array = []
    users.all.each do |user|
      array.push(user[:owner_user_id])
    end

    return array
  end
end