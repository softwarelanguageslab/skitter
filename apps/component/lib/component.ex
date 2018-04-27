# ------------ #
# Error Module #
# ------------ #

defmodule Skitter.Component.DefinitionError do
  @moduledoc """
  This error is raised when a component definition is invalid.
  """
  defexception [:message]
  def exception(val), do: %__MODULE__{message: val}

  @doc """
  Return a quoted raise statement which can be injected by a macro.

  When activated, the statement will raise a DefinitionError with `reason`.
  """
  def inject_error(reason) do
    quote do
      import unquote(__MODULE__)
      raise Skitter.Component.DefinitionError, unquote(reason)
    end
  end
end

defmodule Skitter.Component do
  @moduledoc """
  """

  import Skitter.Component.DefinitionError

  # ------------------- #
  # Component Interface #
  # ------------------- #

  @doc """
  Returns the name of a component.

  The name of a component is automatically generated based on the component
  name provided to `component/3`.
  """
  def name(comp), do: comp.__skitter_metadata__.name

  @doc """
  Returns the description of a component.

  The description of a component can be provided by adding a string as the first
  element of the `component/3` body.
  An empty string is returned if no documentation is present.

  ## Example

  ```
  component Example, in: [:in], out: [:out] do
    "Your description goes here"
  end
  ```
  """
  def description(comp), do: comp.__skitter_metadata__.description

  @doc """
  Return the effects of a component.

  TODO: Add more information about this later.
  """
  def effects(comp), do: comp.__skitter_metadata__.effects

  @doc """
  Return the in ports of a component.

  TODO: Add more information about this later.
  """
  def in_ports(comp), do: comp.__skitter_metadata__.in_ports

  @doc """
  Return the in ports of a component.

  TODO: Add more information about this later.
  """
  def out_ports(comp), do: comp.__skitter_metadata__.out_ports

  # -------------------- #
  # Component Generation #
  # -------------------- #

  # Constants
  # ---------

  @valid_effects [internal_state: [], external_effects: []]

  @component_callbacks [:react, :init]

  # Main Definition
  # ---------------

  @doc """
  Create a skitter component.
  """
  defmacro component(name, ports, do: body) do
    # Get metadata from header
    full_name = full_name(Macro.expand(name, __CALLER__))
    {in_ports, out_ports} = read_ports(ports)

    # Extract metadata from body AST
    {body, desc} = extract_description(body)
    {body, effects} = extract_effects(body)

    # Gather metadata
    metadata = %{
      name: full_name,
      description: desc,
      effects: effects,
      in_ports: in_ports,
      out_ports: out_ports
    }

    # Transform macro calls inside body AST
    body = transform_component_callbacks(body, metadata)

    # Check for errors
    errors = check_component_body(metadata, body)

    quote do
      defmodule unquote(name) do
        import unquote(__MODULE__).Internal,
          only: [
            react: 3,
            init: 3
          ]

        def __skitter_metadata__, do: unquote(Macro.escape(metadata))

        unquote(errors)
        unquote(body)
      end
    end
  end

  # AST Transformation
  # ------------------
  # Transformations applied to the body provided to component/3

  # Extract effect declarations from the AST and add the effects to the effect
  # list.
  # Effects are specified as either:
  #  effect effect_name property1, property2
  #  effect effect_name
  # In both cases, the full statement will be removed from the ast, and the
  # effect will be added to the accumulator with its properties.
  defp extract_effects(body) do
    Macro.postwalk(body, [], fn
      {:effect, _env, [effect]}, acc ->
        {effect, properties} = Macro.decompose_call(effect)
        properties = Enum.map(properties, fn {name, _env, _args} -> name end)
        {nil, Keyword.put(acc, effect, properties)}

      any, acc ->
        {any, acc}
    end)
  end

  # Transform all calls to macros in the `@component_callbacks` list to calls
  # where all the arguments (except for the do block, which is the final
  # argument) are wrapped inside a list. Provide the component metadata and
  # do block as the second and third argument.
  # Thus, a call to macro `foo(a,b) do ...` turns into `foo([a,b], meta) do ...`
  # This makes it possible to use arbitrary pattern matching in `react`, etc
  # It also provides the various callbacks information about the component.
  # Furthermore, any calls to helper are transformed into `defp`
  defp transform_component_callbacks(body, meta) do
    Macro.postwalk(body, fn
      {name, env, arg_lst}
      when name in @component_callbacks ->
        {args, [block]} = Enum.split(arg_lst, -1)
        {name, env, [args, meta, block]}

      {:helper, env, rest} ->
        {:defp, env, rest}

      any ->
        any
    end)
  end

  # Data Extraction
  # ---------------
  # Functions used when expanding the component/3 macro

  # Generate a readable string (i.e. a string with spaces) based on the name
  # of a component.
  defp full_name(name) do
    name = name |> Atom.to_string() |> String.split(".") |> Enum.at(-1)
    regex = ~r/([[:upper:]]+(?=[[:upper:]]|$)|[[:upper:]][[:lower:]]*)/
    regex |> Regex.replace(name, " \\0") |> String.trim()
  end

  # Parse the port lists, add an empty list for out ports if they are not
  # provided
  defp read_ports(in: in_ports), do: read_ports(in: in_ports, out: [])
  defp read_ports(in: in_ports, out: out_ports) do
    {parse_port_names(in_ports), parse_port_names(out_ports)}
  end

  # Transform bare elixir names into symbols.
  #   e.g: port list [foo, bar] becomes [:foo, :bar]
  # If something other than a non-elixir name is encountered, add an error that
  # can be filtered out by `check_port_names/1` later.
  defp parse_port_names(lst) when is_list(lst) do
    Enum.map(lst, fn
      {name, _env, nil} -> name
      any -> {:error, any}
    end)
  end

  # Allow single names to be specified outside of a list
  #   e.g. in: foo will become in: [foo]
  # The list variant of this function will ensure the elements are provided in a
  # correct format.
  defp parse_port_names(el), do: parse_port_names([el])

  # Retrieve the description from a component if it is present.
  # A description is provided when the component body start with a string.
  # If this is the case, remove the string from the body and use it as the
  # component description.
  # If it is not the case, leave the component body untouched.
  defp extract_description({:__block__, env, [str | r]}) when is_binary(str) do
    {{:__block__, env, r}, str}
  end

  defp extract_description(str) when is_binary(str),
    do:
      {quote do
       end, str}

  defp extract_description(any), do: {any, ""}

  # Error Checking
  # --------------
  # Functions that check if the component as a whole is correct

  defp check_component_body(meta, _body) do
    [
      check_effects(meta),
      check_port_names(meta[:in_ports]),
      check_port_names(meta[:out_ports])
    ]
  end

  defp check_port_names(list) do
    case Enum.find(list, &(match?({:error, _}, &1))) do
      {:error, val} ->
        inject_error "`#{val}` is not a valid port"
      nil -> nil
    end
  end

  # Check if the specified effects are valid.
  # If they are, ensure their properties are valid as well.
  defp check_effects(metadata) do
    for {effect, properties} <- metadata[:effects] do
      with valid when valid != nil <- Keyword.get(@valid_effects, effect),
           [] <- Enum.reject(properties, fn p -> p in valid end) do
        nil
      else
        nil ->
          inject_error "Effect `#{effect}` is not valid"

        [prop | _] ->
          inject_error "`#{prop}` is not a valid property of `#{effect}`"
      end
    end
  end

  # ------------------- #
  # Component Callbacks #
  # ------------------- #

  defmodule Internal do
    @moduledoc """
    Macros to be used inside `Skitter.Component.component/3`

    __This module is automatically imported by `Skitter.Component.component/3`,
    do not import it manually.__

    The Macros in this module are used inside the body of
    `Skitter.Component.component/3` to generate a component definition.
    Be sure to read its documentation before proceeding.

    ## Warning

    Calls to the macros in this module are often modified by the
    `Skitter.Component.component/3` macro.
    Therefore, you cannot always call the macros in this module like you
    would expect.
    The documentation in this module is only present for extra explanation,
    __do not manually call these macros outside of the body of
    `Skitter.Component.component/3`.__
    The documentation will contain examples of the correct syntax of the use of
    these macros when needed.
    """

    import Skitter.Component.DefinitionError

    @doc """
    Fetch the current component instance.

    Elixir will emit warnings about the `skitter_instance` variable if some
    error with the instance variable occurs.

    Usable inside `react/3`, `init/3`.
    """
    defmacro instance do
      quote do
        var!(skitter_instance)
      end
    end

    @doc """
    Modify the instance of the component, __do not call this directly__.

    Automatically generated when `instance = something` is encountered inside a
    component callback.
    Usable inside `init/3`, and inside `react/3` iff the component is marked
    with the `:internal_state` effect.

    Elixir will emit warnings about the `skitter_instance` variable if some
    error with the instance variable occurs.

    ## Example

    ```
    component MyComponent, in: [:foo, :bar] do
      init external_value do
        instance = external_value
      end
    end
    """
    defmacro instance(value) do
      quote generated: true do
        var!(skitter_instance) = unquote(value)
      end
    end

    defmacro init(args, _meta, do: body) do
      quote do
        def __skitter_init__(unquote(args)) do
          import unquote(__MODULE__), only: [instance: 1]
          unquote(body)
          {:ok, var!(skitter_instance)}
        end
      end
    end

    # ---------------- #
    # React Generation #
    # ---------------- #

    # TODO:
    #   - postwalk to check for instance use
    defmacro react(args, meta, do: body) do
      errors = check_react_body(args, meta, body)

      {output_pre, output_post} = create_react_output(args, meta, body)

      body =
        quote do
          import unquote(__MODULE__), only: [spit: 2]
          unquote(output_pre)
          unquote(body)
          {:ok, var!(skitter_instance), unquote(output_post)}
        end

      react_body = remove_after_failure(body)
      react_after_failure_body = build_react_after_failure_body(body, meta)

      quote do
        unquote(errors)

        def __skitter_react__(instance, unquote(args)) do
          unquote(react_body)
        end

        def __skitter_react_after_failure__(instance, unquote(args)) do
          unquote(react_after_failure_body)
        end
      end
    end

    # Internal Macros
    # ---------------

    @doc """
    Provide a value to the workflow on a given port.

    The given value will be sent to every other component that is connected to
    the provided output port of the component.
    The value will be sent _after_ `react/3` has finished executing.

    Usable inside `react/3` iff the component has an output port.
    """
    defmacro spit(port, value) do
      quote do
        var!(skitter_output) =
          Keyword.put(
            var!(skitter_output),
            unquote(port),
            unquote(value)
          )
      end
    end

    @doc """
    Code that should only be executed after a failure occurred.

    The code in this block will only be executed if `react/3` is triggered
    after a failure occurred.
    Internally, this operation is a no-op. Post walks will filter out calls
    to this macro when needed.

    Usable inside `react/3` iff the component has an external state.
    """
    defmacro after_failure(do: body), do: body

    # AST Creation
    # ------------

    # Generate the ASTs for creating the initial value and reading the value
    # of skitter_output.
    def create_react_output(_args, _meta, body) do
      spit_use_count = count_occurrences(:spit, body)

      if spit_use_count > 0 do
        {
          quote do
            var!(skitter_ouput) = []
          end,
          quote do
            var!(skitter_ouput)
          end
        }
      else
        {nil, nil}
      end
    end

    # Create the body of __skitter_react_after_failure depending on the
    # effects of the components.
    defp build_react_after_failure_body(body, meta) do
      if Keyword.has_key?(meta[:effects], :external_effects) do
        quote do
          import unquote(__MODULE__), only: [after_failure: 1]
          unquote(body)
        end
      else
        remove_after_failure(body)
      end
    end

    # AST Transformations
    # -------------------

    defp remove_after_failure(body) do
      Macro.postwalk(body, fn
        {:after_failure, _env, _args} -> nil
        any -> any
      end)
    end

    # Error Checking
    # --------------

    # Check the body of react for some common errors.
    defp check_react_body(args, meta, body) do
      cond do
        # Ensure the inputs can map to the provided argument list
        length(args) != length(meta[:in_ports]) ->
          inject_error "Different amount of arguments and in_ports"

        # Ensure all spits are valid
        (p = check_spits(meta[:out_ports], body)) != nil ->
          inject_error "Port `#{p}` not in out_ports"

        # Ensure after_failure is only used when there are external effects
        count_occurrences(:after_failure, body) > 0 and
            !Keyword.has_key?(meta[:effects], :external_effects) ->
          inject_error(
            "`after_failure` only allowed when external_effects are present"
          )

        true ->
          nil
      end
    end

    # Check the spits in the body of react through `port_check_postwalk/2`
    defp check_spits(ports, body) do
      {_, {_ports, port}} =
        Macro.postwalk(body, {ports, nil}, &port_check_postwalk/2)

      port
    end

    # Check all the calls to spit and verify that the output port exists.
    # If it does not, put the output port in the accumulator
    defp port_check_postwalk(ast = {:spit, _env, [port, _val]}, {ports, nil}) do
      if port in ports, do: {ast, {ports, nil}}, else: {ast, {ports, port}}
    end

    # Fallback match, don't do anything
    defp port_check_postwalk(ast, acc), do: {ast, acc}

    # ----------------- #
    # Utility Functions #
    # ----------------- #

    # Count the occurrences of a given symbol in an ast.
    defp count_occurrences(symbol, ast) do
      {_, n} =
        Macro.postwalk(ast, 0, fn
          ast = {^symbol, _env, _args}, acc -> {ast, acc + 1}
          ast, acc -> {ast, acc}
        end)

      n
    end
  end
end
