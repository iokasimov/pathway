# Well-typed paths: revisited

Despite the fact that there are several “path” libraries in Haskell, I decided to write a new one I would like to use.

Problem description
--------------------------------------------------------------------------------
Often (when you write a useful program) you need to do something to the filesystem. Using temporary files, reading directory contents, writing logs - in all of these cases you need to clarify the path. But path can be specified either in absolute or relative form, or be relative to some absolute path called `home`. And it can point either to a directory or a file. Instead of encoding these cases directly as type sums, we will do some trick.

The absolute path is just a path that relative to the root, the same for the home and current working directory. Let's create a type that indicates subject of relativity:

```haskell
data Origin = Root | Now | Home | Early | Vague
```

And a sum type shows which object we point to:
```haskell
data Points = Directory | File
```

We use stack as a core data structure for path, so our type is:
```haskell
{-# language DataKinds, KindSignatures #-}

newtype Outline (origin :: Origin) (points :: Points) =
	Outline { outline :: Cofree Maybe String }
```

We can split our paths on groups:
```haskell
type Incompleted = Relative | Current | Homeward | Previous
type Certain = Absolute | Current | Homeward | Previous
```

Now we need some rules that can help us build valid paths depending on theirs types. So, we can do this:

```haskell
Incompleted Path To Directory + Relative Path To Directory = Relative Path To Directory
"usr/local/" + "etc/" = "usr/local/etc/"
Incompleted Path To Directory + Relative Path To File = Relative Path To File
"bin/" + "git" = "bin/git"
Absolute Path To Directory + Incompleted Path To Directory = Absolute Path To Directory
"/usr/local/" + "etc/" = "/usr/local/etc/" =
Absolute Path To Directory + Incompleted Path To File = Absolute Path To File
"/usr/bin/" + "git" = "/usr/bin/git"
```

But we can't do this:

```haskell
_ Path To File + _ Path To File = ???
_ Path To File + _ Path To Directory = ???
Absolute Path To _ + Absolute Path To _ = ???
Incompleted Path To _ + Absolute Path To _ = ???
```

Based on these rules we can define two generalized combinators. `Current`, `Homeward`, `Previous` and `Relative` paths are the same internally, they are different only for type system.

```haskell
(<^>) :: Incompleted Path To Directory -> Relative Path To points -> Relative Path To points
(</>) :: Absolute Path To Directory -> Incompleted Path To points -> Absolute Path To points
```

And, if you want improve your code readability, you can use specialized combinators:

```haskell
-- Add relative path to incompleted path:
(<.^>) :: Current Path To Directory -> Relative Path To points -> Currently Path To points
(<~^>) :: Homeward Path To Directory -> Relative Path To points -> Homeward Path To points
(<-^>) :: Previous Path To Directory -> Relative Path To points -> Previous Path To points
(<^^>) :: Relative Path To Directory -> Relative Path To points -> Relative Path To points
-- Absolutize incompleted path:
(</.>) :: Absolute Path To Directory -> Current Path To points -> Absolute Path To points
(</~>) :: Absolute Path To Directory -> Homeward Path To points -> Absolute Path To points
(</->) :: Absolute Path To Directory -> Previous Path To points -> Absolute Path To points
(</^>) :: Absolute Path To Directory -> Relative Path To points -> Absolute Path To points
```

Get our hands dirty
--------------------------------------------------------------------------------

There are some functions in [`System.Monopati.Posix.Calls`](https://github.com/iokasimov/monopati/blob/master/System/Monopati/Posix/Calls.hs) that work with our Path definition:

* As you may remember, we use Stack - it's an not empty inductive data structure. When we are in a root, we have no directory or file to point in - we are in the starting point, so `current` returns `Nothing`. We return absolute path because we actually want to know where we are exactly in the filesystem:
```haskell
current :: IO (Maybe (Absolute Path To Directory))
```
* Sometimes we want to change our current working directory for some reason. As documentation of [`System.Directory`](http://hackage.haskell.org/package/directory-1.3.3.1/docs/System-Directory.html#v:setCurrentDirectory) says: it's highly recommended to use absolute rather than relative paths cause of current working directory is a global state shared among all threads:
```haskell
change :: Absolute Path To Directory -> IO (Absolute Path To Directory)
```

* Creating and removing directories with absolute paths only:
```haskell
create :: Absolute Path To Directory -> IO ()
remove :: Absolute Path To Directory -> IO ()
```

Simple example of usage
--------------------------------------------------------------------------------

Let's imagine that we need to save some content in temporary files grouped on folders based on some prefix.

```haskell
mkdir :: String -> IO (Absolute Path To Directory)
mkdir prefix = create $ part "Temporary" <^> part prefix

filepath :: String -> String -> IO (Absolute Path To File)
filepath filename prefix = (\dir -> dir </> part filename) <$> mkdir prefix
```

In this example, `part` function is like a `pure` for `Path` but it takes strings only. We create a directory and then construct a full path to the file.

As you can understand, this library motivates you use only absolute paths, but not force it.

Motivation of using this library
--------------------------------------------------------------------------------

* Concatenating paths is more efficient, instead of linear time for lists, it's Rope-like structure.
* It uses two generalized combinators and six specialized instead of one for code readability. When you see them in the code you already know which paths you concatenate.

Well, it's easier for me to define what exactly I don't like in another "path"-libraries:

* [`filepath`](https://hackage.haskell.org/package/filepath) - The most popular, but using raw strings.
* [`path`](https://hackage.haskell.org/package/path) - TemplateHaskell (I really hate it), using raw strings in internals.
* [`posix-paths`](https://github.com/JohnLato/posix-paths) - Focusing on performance instead of usage simplicity.
