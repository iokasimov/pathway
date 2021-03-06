module System.Monopati.Posix.Combinators
	( deeper, part, parent, unparent
	, (<^>), (<.^>), (<~^>), (<-^>), (<^^>)
	, (</>), (</.>), (</~>), (</->), (</^>)) where

import "base" Data.Eq (Eq ((/=)))
import "base" Data.Function ((.), ($), (&))
import "base" Data.Functor ((<$>))
import "base" Data.List (filter)
import "base" Data.Maybe (Maybe (Just, Nothing))
import "base" Data.String (String)
import "free" Control.Comonad.Cofree (Cofree ((:<)), unwrap)
import "peano" Data.Peano (Peano (Zero, Succ))

import System.Monopati.Posix.Core
	( Points (..), Origin (..), Dummy (For, To), Path, Outline (..), Parent (..)
	, Absolute, Current, Homeward, Previous, Relative, Incompleted, Parental)

-- | Immerse string into a path, filter slashes
part :: String -> Outline origin points
part x = Outline $ (filter (/= '/') x) :< Nothing

-- | Add relative path to uncompleted path
(<^>) :: forall origin points . Incompleted origin =>
	Outline origin Directory -> Relative Path To points -> Outline origin points
Outline (x :< Nothing) <^> Outline that = Outline $ x :< Just that
Outline (x :< Just this) <^> Outline that = (<^>) (part @origin x)
	$ (<^>) @Vague (Outline this) (Outline that)

{-| @
".//etc///" + "usr///local///" + = ".///etc///usr///local//"
@ -}
(<.^>) :: Current Path To Directory -> Relative Path To points -> Current Path To points
currently <.^> relative = currently <^> relative

{-| @
"~//etc///" + "usr///local///" + = "~///etc///usr///local//"
@ -}
(<~^>) :: Homeward Path To Directory -> Relative Path To points -> Homeward Path To points
homeward <~^> relative = homeward <^> relative

{-| @
"-//etc///" + "usr///local///" + = "-///etc///usr///local//"
@ -}
(<-^>) :: Previous Path To Directory -> Relative Path To points -> Previous Path To points
previous <-^> relative = previous <^> relative

{-| @
"etc//" + "usr///local///" + = "etc///usr///local//"
@ -}
(<^^>) :: Relative Path To Directory -> Relative Path To points -> Relative Path To points
relative' <^^> relative = relative' <^> relative

-- | Absolutize uncompleted path
(</>) :: forall origin points . Incompleted origin =>
	Absolute Path To Directory-> Outline origin points -> Absolute Path To points
Outline absolute </> Outline (x :< Nothing) = Outline . (:<) x . Just $ absolute
Outline absolute </> Outline (x :< Just xs) = (</>) @origin (Outline . (:<) x . Just $ absolute) $ Outline xs

{-| @
"//usr///local///" + ".///etc///" = "///usr///local///etc//"
@ -}
(</.>) :: Absolute Path To Directory -> Current Path To points -> Absolute Path To points
absolute </.> currently = absolute </> currently

{-| @
"//usr///local///" + "-///etc///" = "///usr///local///etc//"
@ -}
(</~>) :: Absolute Path To Directory -> Homeward Path To points -> Absolute Path To points
absolute </~> homeward = absolute </> homeward

{-| @
"//usr///local///" + "~///etc///" = "///usr///local///etc//"
@ -}
(</->) :: Absolute Path To Directory -> Previous Path To points -> Absolute Path To points
absolute </-> previous = absolute </> previous

{-| @
"//usr///bin///" + "git" = "///usr///bin//git"
@ -}
(</^>) :: Absolute Path To Directory -> Relative Path To points -> Absolute Path To points
absolute </^> relative = absolute </> relative

unparent :: Parental For (Outline origin Directory) -> Maybe (Outline origin Directory)
unparent (Parent Zero outline) = Just outline
unparent (Parent (Succ n) (Outline (x :< Nothing))) = Nothing
unparent (Parent (Succ n) (Outline (x :< Just xs))) = unparent . Parent n $ Outline xs

-- | Take parent directory of current pointed entity
parent :: Absolute Path To points -> Maybe (Absolute Path To Directory)
parent = (<$>) Outline . unwrap . outline

-- | Take the next piece of relative path
deeper :: Relative Path To points -> Maybe (Relative Path To points)
deeper = (<$>) Outline . unwrap . outline
