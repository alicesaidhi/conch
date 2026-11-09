# draft conch 0.5.0 api

conch.VERSION

conch.users.create(player?)
conch.users.add_role(user, role)
conch.users.remove_role(user, role)
conch.users.get_user(player_or_key)
conch.users.server_user: User

conch.auth.set_permissions(role, permissions: {})
conch.auth.get_permissions_for_role(role)
conch.auth_get_permissions_for_player(player)
conch.auth.recheck_permissions_for(user)
conch.auth.hook_before_run(fn)
conch.auth.has_permissions(user, ...)
conch.auth.SUPER_USER -- role, allows access to all commands
conch.auth.VIEW_FULL_SERVER_LOGS -- permission to view server logs
conch.auth.ANYONE_CAN_EXECUTE -- permission to allow everyone to execute a command
conch.auth.UNBOUNDED -- permission, ignores any rate limits set on commands
conch.auth.SAVE_STATE -- role, allows state to be saved

conch.executor.run_string(user, string): thread
conch.executor.run_command(user, commandname, arguments): thread
conch.executor.read_variable(user, var): any
conch.executor.set_variable(user, var, value)
conch.executor.analyze(user, string, cursor_position): Analysis
conch.executor.get_running_context(): Context?
conch.executor.obtain_executor_state(user): State -- some of it can be saved
conch.executor.after_execution(callback)
conch.executor.on_execution(callback)

conch.command.register(props): Command
conch.command.unregister(command_name): boolean
conch.command.after_command_ran(callback)
conch.command.get_commands()

conch.output.log(string)

conch.ayalog.sink

conch.network.set_rate_limits(limits)

conch.storage.enable()

conch.types.player(name, desc)
conch.types.players(name, desc)
... not listing everything
conch.types.union(...)
conch.types.struct({})

conch.types.get_extern_type(name)
conch.types.unregister_extern_type()
conch.types.register_extern_type(strangetype)
conch.types.pluralize_type(strangetype)
conch.types.wrap_type(type)

conch.bootstrap.register_default_commands()
conch.bootstrap.initiate_default_lifecycle()
