# This "model" is not backed by the database. Its main purpose is to
# setup and provide methods to interact with the admin sidebar and tabbed menu
class AdminMenu
  # On second level navigation with more children, we reference the default tabs controller. i.e look at developer_tools
  # rubocop:disable Metrics/BlockLength
  FEATURE_FLAGS = %i[profile_admin data_update_scripts].freeze

  ITEMS = Menu.define do
    scope :people, "group-2-line", [
      item(name: "people", controller: "users", parent: "users"),
    ]

    scope :content_manager, "dashboard-line", [
      item(name: "posts", controller: "articles"),
      item(name: "comments", controller: "comments"),
      item(name: "badges", children: [
             item(name: "library", controller: "badges"),
             item(name: "achievements", controller: "badge_achievements"),
           ]),
      item(name: "organizations"),
      item(name: "podcasts"),
      item(name: "tags"),
    ]

    scope :customization, "tools-line", [
      item(name: "config"),
      item(name: "html variants", controller: "html_variants"),
      item(name: "display ads"),
      item(name: "navigation links"),
      item(name: "pages"),
      item(name: "profile fields", visible: false),
    ]

    scope :admin_team, "user-line", [
      item(name: "admin team", controller: "permissions", parent: "permissions"),
    ]

    scope :moderation, "mod", [
      item(name: "reports"),
      item(name: "mods"),
      item(name: "moderator actions ads", controller: "moderator_actions"),
      item(name: "privileged reactions"),
    ]

    scope :advanced, "flashlight-line", [
      item(name: "broadcasts"),
      item(name: "response templates"),
      item(name: "sponsorships"),
      item(name: "developer tools", controller: "tools", children: [
             item(name: "tools"),
             item(name: "vault secrets", controller: "secrets"),
             item(name: "data update scripts", visible: false),
             item(name: "extensions", controller: "extensions"),
           ]),
    ]

    scope :apps, "palette-line", [
      item(name: "consumer apps", controller: "consumer_apps"),
      item(name: "listings"),
      item(name: "welcome"),
    ]
  end.freeze
  # rubocop:enable Metrics/BlockLength

  def self.navigation_items
    return ITEMS unless FEATURE_FLAGS.any? { |flag| FeatureFlag.enabled?(flag) }

    feature_flagged_menu_items
  end

  # Return the Menu item that corresponds to the nav_item within the given named scope.
  #
  # @param scope_name [String] a slug from the request.path, which, by convention maps to the scope
  #        declarations in {ITEMS}.
  # @param nav_item [String] a slug from the request.path, which, by convention maps to the item
  #        declarations that are one level below the scope declarations of {ITEMS}.
  #
  # @return [NilClass] when we don't have a menu representation of the nav_item
  # @return [Hash] the representation of the nav_item
  #
  # @todo This method returns the nav_item, but we really only operate on that item's children.
  #       Consider replacing with a method that is "children of nav_item within scope".
  #
  # @see AdminMenu.nested_menu_items_from_request
  # @see AdminMenu::ITEMS
  def self.nested_menu_items(scope_name, nav_item)
    return unless navigation_items.dig(scope_name.to_sym, :children)

    navigation_items.dig(scope_name.to_sym, :children).each do |items|
      return items if items[:controller] == nav_item

      next unless items[:children]&.any?

      items[:children].each do |child|
        # NOTE: [@jeremyf] trying to puzzle this one out.  My read is that if the "grandchild" of the
        # scope matches the controller, return the parent node (e.g. the item).
        return items if child[:controller] == nav_item
      end
    end

    # Because we're using each loops, with short-circuiting returns, we need to make sure we don't
    # return the results of `items[:children].each`, which will be `items[:children]`.
    nil
  end

  # @param request [#path] the request object (which must respond to `#path`)
  # @return [NilClass] when we don't have a menu representation of the nav_item
  # @return [Hash] the representation of the nav_item
  #
  # @see {.nested_menu_items} for implementation details
  #
  # @note This method assumes that the last two slugs of the request's path are the relevant
  #       information for determining which menu item to return.  In other words, strongly consider
  #       the impact of having admin routes whose paths are comprised of more than 3 slugs (.e.g. we
  #       assume /admin/:scope_name/:nav_item but be wary of /admin/something/:scope_name/:nav_item
  #       or /admin/:scope_name/something/:nav_item).
  def self.nested_menu_items_from_request(request)
    scope, nav_item = request.path.split("/").last(2)
    nested_menu_items(scope, nav_item)
  end

  def self.feature_flagged_menu_items
    # We default to creating a ITEMS constant with visibility set to false
    # and then simply amend the visibility of the feature flag when it's
    # turned on, instead of creating the payload dynamically each time.
    menu_items = ITEMS.deep_dup

    if FeatureFlag.enabled?(:profile_admin)
      profile_hash = menu_items.dig(:customization, :children).detect { |item| item[:controller] == "profile_fields" }
      profile_hash[:visible] = true
    end

    if FeatureFlag.enabled?(:data_update_scripts)
      data_update_script_hash = menu_items.dig(:advanced, :children)
        .detect { |item| item[:controller] ==  "tools" }[:children]
        .detect { |item| item[:controller] ==  "data_update_scripts" }
      data_update_script_hash[:visible] = true
    end

    menu_items
  end
end
