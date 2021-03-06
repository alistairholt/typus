module Typus

  module Authentication

    module Session

      protected

      include Base

      def authenticate
        if session[:typus_user_id]
          current_user
        else
          back_to = request.env['PATH_INFO'] unless [admin_dashboard_path, admin_path].include?(request.env['PATH_INFO'])
          redirect_to new_admin_session_path(:back_to => back_to)
        end
      end

      #--
      # Return the current user. If role does not longer exist on the
      # system current_user will be signed out from Typus.
      #++
      def current_user
        @current_user ||= Typus.user_class.find_by_id(session[:typus_user_id])

        if !@current_user || !Typus::Configuration.roles.has_key?(@current_user.role) || !@current_user.status
          session[:typus_user_id] = nil
          redirect_to new_admin_session_path
        end

        @current_user
      end

      #--
      # Action is available on: edit, update, toggle and destroy
      #++
      def check_if_user_can_perform_action_on_user
        return unless @item.is_a?(Typus.user_class)

        case params[:action]
        when 'edit'
          not_allowed if current_user.is_not_root? && (current_user != @item)
        when 'update'
          user_profile = (current_user.is_root? || current_user.is_not_root?) && (current_user == @item) && !(@item.role == params[@object_name][:role])
          other_user   = current_user.is_not_root? && !(current_user == @item)
          not_allowed if (user_profile || other_user)
        when 'toggle', 'destroy'
          root = current_user.is_root? && (current_user == @item)
          user = current_user.is_not_root?
          not_allowed if (root || user)
        end
      end

      #--
      # This method checks if the user can perform the requested action.
      # It works on models, so its available on the `resources_controller`.
      #++
      def check_if_user_can_perform_action_on_resources
        if !@item.is_a?(Typus.user_class) && current_user.cannot?(params[:action], @resource)
          not_allowed
        end
      end

      #--
      # This method checks if the user can perform the requested action.
      # It works on a resource: git, memcached, syslog ...
      #++
      def check_if_user_can_perform_action_on_resource
        resource = params[:controller].remove_prefix.camelize
        unless current_user.can?(params[:action], resource, { :special => true })
          not_allowed
        end
      end

      def not_allowed
        render :text => "Not allowed!", :status => :unprocessable_entity
      end

      #--
      # If item is owned by another user, we only can perform a
      # show action on the item. Updated item is also blocked.
      #
      #   before_filter :check_resource_ownership, :only => [ :edit, :update, :destroy,
      #                                                       :toggle, :position,
      #                                                       :relate, :unrelate ]
      #++
      def check_resource_ownership
        return if current_user.is_root?

        condition_typus_users = @item.respond_to?(Typus.relationship) && !@item.send(Typus.relationship).include?(current_user)
        condition_typus_user_id = @item.respond_to?(Typus.user_fk) && !@item.owned_by?(current_user)

        not_allowed if (condition_typus_users || condition_typus_user_id)
      end

      #--
      # Show only related items it @resource has a foreign_key (Typus.user_fk)
      # related to the logged user.
      #++
      def check_resource_ownerships
        if current_user.is_not_root? && @resource.typus_user_id?
          condition = { Typus.user_fk => current_user }
          @conditions = @resource.merge_conditions(@conditions, condition)
        end
      end

      def set_attributes_on_create
        if @resource.typus_user_id?
          @item.attributes = { Typus.user_fk => current_user.id }
        end
      end

      def set_attributes_on_update
        if @resource.typus_user_id? && current_user.is_not_root?
          @item.update_attributes(Typus.user_fk => current_user.id)
        end
      end

      #--
      # Reload current_user when updating to see flash message in the
      # correct locale.
      #++
      def reload_locales
        if @resource.eql?(Typus.user_class)
          I18n.locale = current_user.reload.preferences[:locale]
        end
      end

    end

  end

end
