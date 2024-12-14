-- simple_christmas/init.lua
-- The simple, elegant christmas mod
-- SPDX-License-Identifier: MIT

local S = core.get_translator("simple_christmas")

local materials = xcompat.materials
local sound_api = xcompat.sounds

-- Don't use group:food_egg cuz that includes cooked egg
for _, name in ipairs({
    "animalia:chicken_egg",
    "animalia:turkey_egg",
    "animalia:song_bird_egg",
    "mobs:egg",
    "mcl_throwing:egg",
}) do
    local def = core.registered_items[name]
    if def then
        local groups = table.copy(def.groups)
        groups.simple_christmas_egg_raw = 1
        core.override_item(name, {
            groups = groups,
        })
    end
end

local drinking_glass =
    core.registered_items["vessels:drinking_glass"] and "vessels:drinking_glass" or materials.glass_bottle

local milk =
    core.registered_items["mcl_mobitems:milk_bucket"] and "mcl_mobitems:milk_bucket" or "group:food_milk"

core.register_craftitem("simple_christmas:candy_cane", {
    description = S("Candy Cane"),
    inventory_image = "simple_christmas_candy_cane.png",
    on_use = core.item_eat(1),
})

core.register_craftitem("simple_christmas:mince_pie", {
    description = S("Mince Pie"),
    inventory_image = "simple_christmas_mincepie.png",
    on_use = core.item_eat(6)
})

if core.registered_items["farming:gingerbread_man"] then
    core.register_alias("simple_christmas:gingerbread_man", "farming:gingerbread_man")

    -- Clear old craft cuz it uses group:food_egg
    core.clear_craft({
        output = "farming:gingerbread_man",
    })
else
    core.register_craftitem("simple_christmas:gingerbread_man", {
        description = S("Gingerbread Man"),
        inventory_image = "simple_christmas_gingerbread_man.png",
        on_use = core.item_eat(2),
    })
end

core.register_node("simple_christmas:eggnog", {
    description = S("Eggnog"),
    drawtype = "plantlike",
    tiles = { "simple_christmas_eggnog.png" },
    inventory_image = "simple_christmas_eggnog.png",
    wield_image = "simple_christmas_eggnog.png",
    on_use = core.item_eat(10, materials.glass_bottle),
    groups = { vessel = 1, dig_immediate = 3, attached_node = 1 },
    paramtype = "light",
    is_ground_content = false,
    walkable = false,
    selection_box = {
        type = "fixed",
        fixed = { -0.25, -0.5, -0.25, 0.25, 0.3, 0.25 }
    },
    sounds = sound_api.node_sound_glass_defaults(),
})

core.register_node("simple_christmas:milk_glass", {
    description = S("Glass of milk"),
    drawtype = "plantlike",
    tiles = { "simple_christmas_milk_glass.png" },
    inventory_image = "simple_christmas_milk_glass_inv.png",
    wield_image = "simple_christmas_milk_glass.png",
    paramtype = "light",
    is_ground_content = false,
    walkable = false,
    selection_box = {
        type = "fixed",
        fixed = { -0.25, -0.5, -0.25, 0.25, 0.3, 0.25 }
    },
    groups = { vessel = 1, dig_immediate = 3, attached_node = 1 },
    sounds = sound_api.node_sound_glass_defaults(),
    on_use = core.item_eat(4, drinking_glass),
})

local present_node_box = {
    type = "fixed",
    fixed = {
        { -5 / 16, -0.5, -5 / 16, 5 / 16, 2 / 16, 5 / 16 },
    }
}

local present_formspec = "size[8,6]" ..
    "list[context;main;3.5,0.5;1,1;]" ..
    "list[current_player;main;0,1.85;8,1;]" ..
    "list[current_player;main;0,3.08;8,3;8]" ..
    "listring[context;main]" ..
    "listring[current_player;main]"
if core.global_exists("default") then
    present_formspec = present_formspec .. default.get_hotbar_bg(0, 1.85)
end

local function check_and_record_protection(pos, player)
    local name = player:get_player_name()
    if core.is_protected(pos, name) then
        core.record_protection_violation(pos, name)
        return false
    end
    return true
end

local items_backlist = {}
for _, name in ipairs({
    -- Digtron crates - Size not limited
    "digtron:empty_crate",
    "digtron:empty_locked_crate",
    "digtron:loaded_crate",
    "digtron:loaded_locked_crate",

    -- Baskets do proper check so it's fine
}) do
    if core.registered_items[name] then
        items_backlist[name] = true
    end
end

core.register_node("simple_christmas:present", {
    description = S("Christmas present"),
    tiles = { "simple_christmas_present.png" },
    drawtype = "mesh",
    paramtype = "light",
    paramtype2 = "facedir",
    mesh = "simple_christmas_present.obj",
    groups = { snappy = 2, attached_node = 3 },
    selection_box = present_node_box,
    collision_box = present_node_box,
    sounds = sound_api.node_sound_leaves_defaults(),
    stack_max = 1,
    on_construct = function(pos)
        local meta = core.get_meta(pos)
        meta:set_string("infotext", S("Christmas present"))
        meta:set_string("owner", "")
        meta:set_string("formspec", present_formspec)
        local inv = meta:get_inventory()
        inv:set_size("main", 1)
    end,
    preserve_metadata = function(pos, _, _, drops)
        local meta = core.get_meta(pos)
        local inv = meta:get_inventory()
        local item = inv:get_stack("main", 1)
        if item:is_empty() then return end
        local drop = drops[1]
        local drop_meta = drop:get_meta()
        local owner = meta:get_string("owner")
        drop_meta:set_string("main", item:to_string())
        drop_meta:set_string("owner", owner)
        drop_meta:set_string("description", S("Christmas present from @1", owner))
    end,
    on_place = function(itemstack, placer, pointed_thing)
        local name = placer and placer:get_player_name() or ""
        local invert_wall = placer and placer:get_player_control().sneak or false
        return core.rotate_and_place(itemstack, placer, pointed_thing,
            core.is_creative_enabled(name),
            { invert_wall = invert_wall, force_floor = true })
    end,
    after_place_node = function(pos, placer, itemstack)
        if not placer:is_player() then return end
        local meta = core.get_meta(pos)

        local stack_meta = itemstack:get_meta()
        local main_item = stack_meta:get_string("main")

        local owner = stack_meta:get_string("owner")
        if owner == "" then
            owner = placer:get_player_name()
        end
        meta:set_string("owner", owner)
        meta:set_string("infotext", S("Christmas present from @1", owner))

        if main_item ~= "" then
            local inv = meta:get_inventory()
            inv:set_stack("main", 1, ItemStack(main_item))
        end
    end,
    allow_metadata_inventory_move = function(pos, _, _, _, _, count, player)
        return check_and_record_protection(pos, player) and count or 0
    end,
    allow_metadata_inventory_put = function(pos, _, _, stack, player)
        return check_and_record_protection(pos, player) and not items_backlist[stack:get_name()]
            and stack:get_count() or 0
    end,
    allow_metadata_inventory_take = function(pos, _, _, stack, player)
        return check_and_record_protection(pos, player) and stack:get_count() or 0
    end,
    on_metadata_inventory_put = function(pos, _, _, stack, player)
        local name = player:is_player() and player:get_player_name() or "A mod"
        return core.log("action", string.format("%s moves %s %d to present at %s",
            name, stack:get_name(), stack:get_count(), core.pos_to_string(pos)))
    end,
    on_metadata_inventory_take = function(pos, _, _, stack, player)
        local name = player:is_player() and player:get_player_name() or "A mod"
        return core.log("action", string.format("%s takes %s %d from present at %s",
            name, stack:get_name(), stack:get_count(), core.pos_to_string(pos)))
    end,
})

core.register_craft({
    type = "shapeless",
    output = "simple_christmas:mince_pie 3",
    recipe = {
        "group:food_blueberries",
        "group:food_flour",
        "group:food_apple",
        "group:food_blueberries",
        "group:food_sugar"
    },
})

core.register_craft({
    output = "simple_christmas:present",
    recipe = {
        { materials.paper, materials.dye_blue, materials.paper },
        { materials.paper, materials.dye_red,  materials.paper },
        { materials.paper, materials.paper,    materials.paper },
    },
})

core.register_craft({
    output = "simple_christmas:candy_cane 12",
    recipe = {
        { materials.dye_red,  "group:food_sugar",  materials.dye_white },
        { "group:food_sugar", materials.dye_white, "group:food_sugar" },
        { "group:food_sugar", materials.dye_red,   "" },
    },
})

core.register_craft({
    output = "simple_christmas:gingerbread_man 3",
    recipe = {
        { "",                 "group:simple_christmas_egg_raw", "" },
        { "group:food_wheat", "group:food_ginger",              "group:food_wheat" },
        { "group:food_sugar", "",                               "group:food_sugar" }
    }
})

core.register_craft({
    output = "simple_christmas:milk_glass",
    type = "shapeless",
    recipe = { drinking_glass, milk },
    replacements = {
        { "cucina_vegana:soy_milk",  drinking_glass },
        { "farming:soy_milk",        drinking_glass },
        { "mobs:bucket_milk",        materials.empty_bucket },
        { "animalia:bucket_milk",    materials.empty_bucket },
        -- wooden_bucket must exist if wooden_bucket_milk exists/used
        { "mobs:wooden_bucket_milk", "wooden_bucket:bucket_wood_empty" },
    }
})

core.register_craft({
    type = "shapeless",
    output = "simple_christmas:eggnog",
    recipe = {
        milk,
        "group:food_sugar",
        "group:food_sugar",
        "group:simple_christmas_egg_raw",
        materials.glass_bottle,
    },
    replacements = {
        { "cucina_vegana:soy_milk",  drinking_glass },
        { "farming:soy_milk",        drinking_glass },
        { "mobs:bucket_milk",        materials.empty_bucket },
        { "animalia:bucket_milk",    materials.empty_bucket },
        -- wooden_bucket must exist if wooden_bucket_milk exists/used
        { "mobs:wooden_bucket_milk", "wooden_bucket:bucket_wood_empty" },
    }
})
