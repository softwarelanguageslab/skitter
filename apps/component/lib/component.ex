defmodule Skitter.Component do
  @moduledoc """
  A behaviour module to implement and verify Skitter components.
  """

  # --------- #
  # Interface #
  # --------- #

  @doc """
  Return the name of the component.

  _This function is automatically generated when using `component/4`._

  The name of a component is determined as follows:
  - If an `@name` attribute is present in the component definition, this
    attribute will define the name.
  - Otherwise, a name is generated from the name of the macro.
    This name is generated from the final part of the component name.
    Uppercase letters in the module name will be prepended by a space.
    Acronyms are preserved during this transformation.

  ## Examples

  ```
  component ACKFooBar, [] do
    @name Baz
    ...
  end
  ```

  Will have the name "Baz".

  ```
  component ACKFooBar, [] do
    ...
  end
  ```

  Will have the name "ACK Foo Bar".
  """
  @callback name() :: String.t

  @doc """
  Return a detailed description of the component and its behaviour.

  _This function is automatically generated when using `component/4`._

  The description this function returns is obtained from:
  - The string added to the `@desc` module attribute.
  - The documentation added to the `@moduledoc` attribute, if no `@desc`
    attribute is present.
  - An empty string, if neither is present. Skitter will provide a warning when
    this is the case.
  """
  @callback desc() :: String.t

  @doc """
  Return a list of the effects of a component.

  _This function is automatically generated when using `component/4`._

  Please look at the `Skitter.Component` documentation for more information
  about effects.
  """
  @callback effects() :: [:internal_state | :external_effects]

  @doc """
  Return a list of the in_ports of a component.

  _This function is automatically generated when using `component/4`._

  Please look at the `Skitter.Component` documentation for more information
  about ports.
  """
  @callback in_ports() :: [atom(), ...]

  @doc """
  Return a list of the out_ports of a component.

  _This function is automatically generated when using `component/4`._

  Please look at the `Skitter.Component` documentation for more information
  about ports.
  """
  @callback out_ports() :: [atom()]

  @doc """
  Start an instance of the component.

  This callback starts an instance of the reactive component, based on arguments
  which are passed on from a workflow definition.
  If no errors occur, this callback should return a component _instance_, which
  is ready to be used by callbacks such as `c:react/2` and `c:terminate/1`.

  A successful instantiation should return `{:ok, instance}`, where `instance`
  is a valid representation of the component instance.
  Unsuccessful instantiation attempts should return `{:error, message}`, where
  `error` is a string providing some information about the error that occurred.
  """
  @callback init(any()) :: {:ok, any()} | {:error, String.t}

  @doc """
  Make a component instance react to new data.

  This callback will be triggered by the skitter runtime system when there is
  data to be processed.
  The callback will receive a component instance (as generated by `init/1`) and
  a keyword list. This keyword list will contain the arguments that were
  provided for every input port.

  This callback should process its input data and return a new component
  instance. If necessary, the component can also return new values which will
  be passed to the next component in the workflow.

  The returned component instance should be updated with any state changes if
  necessary. The returned values should be provided as a keyword list.
  Each keyword in this list should correspond to an output port of the
  component, the values in this list will be sent to the components connect to
  this particular output port.

  Use the `{:ok, instance, [port: value]}` form when values need to be returned.
  `{:ok, instance}` can be used when no values need to be returned.
  `{:error, message}` can be used to signal an error.

  ## Examples

  The following component acts as a filter and shows how you can return values
  to various ports by using the keyword list:

  ```
  def react(n, [in: x]) when x >  n, do {:ok, n, [greater: x]}
  def react(n, [in: x]) when x <  n, do {:ok, n, [smaller: x]}
  def react(n, [in: x]) when x == n, do {:ok, n, [equal: x]}
  ```

  This component shows how to update the state of a component which calculates
  an average value.

  ```
  def react(%{sum: sum, count: count}, x) do
    sum = sum + x
    count = count + 1
    {:ok, %{sum: sum, count: count}, [out: sum / count]}
  end
  ```
  """
  @callback react(any(), [Keyword.t(),...]) ::
    {:ok, any(), [Keyword.t()]} | {:ok, any()} | {:error, String.t}


  @doc """
  Clean up any resources associated with a component instance.

  This callback is automatically triggered by the skitter runtime when it is
  about to discard a component instance. This should be used to clean up any
  resources a component instance may have acquired.

  If component termination succeeds, return :ok, otherwise, an error can be
  returned.

  The `component/4` macro will automatically generate a terminate function
  which assumes there are no resources to be released.
  """
  @callback terminate(any()) :: :ok | {:error, String.t}

  defmodule DefinitionError do
    @moduledoc """
    This error is raised when a component definition is invalid.
    """
    defexception [:message]

    def exception(val) do
      %DefinitionError{message: val}
    end
  end

  defmodule BadCallError do
    @moduledoc """
    This error is raised when a function is called on a component that does not
    support it (due to its effects)
    """
    defexception [:message]

    def exception(val) do
      %BadCallError{message: val}
    end
  end

  # -------------------- #
  # Component Generation #
  # -------------------- #

  defmodule Transform do
    @moduledoc false

    @doc """
    Transform the effects of a component.

    :no_effects is transformed into an empty list
    atoms are wrapped inside a list
    everything else is left alone.
    """
    def effects(:no_effects), do: []
    def effects(some_atom) when is_atom(some_atom), do: [some_atom]
    def effects(something_else), do: something_else

    @doc """
    Transform the name of a component.

    This is done by modifying the `@name` module attribute.

    If @name is specified, we leave it alone
    Otherwise, we generate a name as specified in the `Skitter.Component.name/0`
    callback.
    """
    def name(env) do
      regex = ~r/([[:upper:]]+(?=[[:upper:]])|[[:upper:]][[:lower:]]*)/
      module = env.module
      name = case Module.get_attribute(module, :name) do
        nil ->
          name = module |> Atom.to_string |> String.split(".") |> Enum.at(-1)
          Regex.replace(regex, name, " \\0") |> String.trim
        name ->
          name
      end
      Module.put_attribute(module, :name, name)
    end

    @doc """
    Transform the description of a component.

    This is done by modifying the `@desc` module attribute.

    If @desc is specified we leave it alone.
    Otherwise, we return an empty description.
    """
    def desc(env) do
      if Module.get_attribute(env.module, :desc) == nil do
        Module.put_attribute(env.module, :desc, "")
      end
    end

    @doc """
    Generate default in ports of a component.

    This is only done if there is no value for `@in_ports`.

    If this value is not provided, we use `[:in]` as value for @in_ports`.
    """
    def in_ports(env) do
      module = env.module
      ports  = case Module.get_attribute(module, :in_ports) do
        nil -> [:in]
        val -> val
      end
      Module.put_attribute(module, :in_ports, ports)
    end

    @doc """
    Generate default out ports of a component.

    This is only done if there is no value for `@out_ports`.

    If this value is not provided, we use `[:out]` as value for @out_ports`.
    """
    def out_ports(env) do
      module = env.module
      ports  = case Module.get_attribute(module, :out_ports) do
        nil -> [:out]
        val -> val
      end
      Module.put_attribute(module, :out_ports, ports)
    end
  end

  defmodule Verify do
    @moduledoc false

    @allowed_effects [:internal_state, :external_effects]

    @doc """
    Ensure effects are valid.

    Empty lists are valid.
    Lists with allowed effects are valid
    Everything else is invalid.
    """
    def effects!([]), do: []

    def effects!(lst) when is_list(lst) do
      case Enum.reject(lst, fn(e) -> e in @allowed_effects end) do
        [] ->
          lst
        errLst ->
          raise DefinitionError, "Invalid effects: #{Enum.join(errLst, ", ")}"
      end
    end

    def effects!(other) do
      raise DefinitionError, "Invalid effect #{inspect(other)}"
    end

    @doc """
    Check if description is present.

    Warn if this is not the case.
    """
    def documentation(env) do
      if Module.get_attribute(env.module, :desc) == "" do
        IO.warn "Missing component documentation"
      end
    end
  end

  defmodule Generate do
    @moduledoc false

    @doc """
    Possibly create "dummy" functions for all internal_state placeholders.

    - If there is an internal_state (true), don't generate any code.
    - If there is no internal_state, generate dummy functions for the functions
      that are only required when an internal state is present.
    """
    def internal_state_placeholders(true), do: nil
    def internal_state_placeholders(false) do
      quote do
        def checkpoint(_) do
          raise BadCallError, "Checkpoint not available without internal state"
        end
        def restore(_) do
          raise BadCallError, "Restore not available without internal state"
        end
      end
    end

    def external_effect_placeholders(true), do: nil
    def external_effect_placeholders(false), do: nil

    defmacro name(env) do
      quote do
        def name, do: unquote(Module.get_attribute(env.module, :name))
      end
    end
    defmacro desc(env) do
      quote do
        def desc, do: unquote(Module.get_attribute(env.module, :desc))
      end
    end
    defmacro in_ports(env) do
      quote do
        def in_ports, do: unquote(Module.get_attribute(env.module, :in_ports))
      end
    end
    defmacro out_ports(env) do
      quote do
        def out_ports, do: unquote(Module.get_attribute(env.module, :out_ports))
      end
    end
  end

  @doc """
  Define a Skitter component.
  """
  defmacro component(name, with: effects, do: body) do
    effects = effects |> Transform.effects |> Verify.effects!
    name = Macro.expand(name, __CALLER__)

    state_body =
      Generate.internal_state_placeholders(:internal_state in effects)
    effect_body =
      Generate.external_effect_placeholders(:external_effects in effects)


    quote do
      defmodule unquote(name) do
        @behaviour Skitter.Component

        # Transform attributes
        @before_compile {Transform, :name}
        @before_compile {Transform, :desc}
        @before_compile {Transform, :in_ports}
        @before_compile {Transform, :out_ports}
        # Generate callbacks
        @before_compile {Generate, :name}
        @before_compile {Generate, :desc}
        @before_compile {Generate, :in_ports}
        @before_compile {Generate, :out_ports}
        # Verify module attributes
        @before_compile {Verify, :documentation}

        # Insert effects function
        def effects, do: unquote(effects)

        # Overridable definitions
        def terminate(_), do: :ok
        defoverridable terminate: 1

        unquote(state_body)
        unquote(effect_body)

        # Insert the provided body
        unquote(body)
      end
    end
  end
end
