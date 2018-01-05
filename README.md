# Objex

Just having fun with macros.

The code (in `lib/objex.ex`) is somewhat commented but it's my first time playing with
the AST so I'm not sure it's any good.

## Demo

```elixir
use Objex
require Logger

class Duck do
  defm on_init(this) do
    this.stamina = 5
    this.speed = 10
    this.x = 0
  end

  defm set_speed(this, speed) when speed > 0,
    do: this.speed = speed
  defm set_speed(this, _), do: Logger.error("Ducks can't go backward")

  defm step(this) do
    if this.stamina > 0 do
      this.x = this.x + this.speed
      this.stamina = this.stamina - 1

      Logger.info("Duck is now at x=#{this.x}")
    else
      Logger.warn("Duck is too tired to go anywhere.")
    end
  end
end
```

```elixir
iex> duck = Duck.new()
iex> Duck.set_speed(duck, 4)
4
iex> Duck.step(duck)
[info]  Duck is now at x=4
:ok
```

## Resources

 -  [The Erlangelist's macro series](http://theerlangelist.com/article/macros_1)
 -  [Compile-time work with Elixir macros](http://andrealeopardi.com/posts/compile-time-work-with-elixir-macros/)


