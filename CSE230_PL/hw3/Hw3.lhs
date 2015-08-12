---
title: Homework #3, Due Friday, March 7th 
---

Preliminaries
=============

> myName  = "Andreas Prodromou"
> myEmail = "aprodrom@eng.ucsd.edu"
> mySID   = "A53049230"

Before starting this part of the assignment, 

1. Install the following packages 

~~~~~{.haskell}
$ cabal install mtl
$ cabal install quickcheck
~~~~~

2. Learn to read the [documentation](http://hackage.haskell.org)

To complete this homework, download [this file](/homeworks/Hw3.lhs) 
as plain text and answer each question, filling in code where it says
`"TODO"`. Your code must typecheck against the given type signatures. 
Feel free to add your own tests to this file to exercise the 
functions you write. Submit your homework by sending this file, 
filled in appropriately, to cse230@goto.ucsd.edu with the subject
“HW3”; you will receive a confirmation email after submitting. 
Please note that this address is unmonitored; if you have any 
questions about the assignment, post to Piazza.

> {-# LANGUAGE TypeSynonymInstances, FlexibleContexts, NoMonomorphismRestriction, OverlappingInstances, FlexibleInstances #-}

> import Data.Map hiding (map, foldr)

> import Control.Monad.State
> import Control.Monad.Error
> import Control.Monad.Writer

> import Test.QuickCheck 
> import Control.Monad (forM, forM_)
> import Data.List (transpose, intercalate)


> quickCheckN n = quickCheckWith $ stdArgs { maxSuccess = n}

Problem 1: An Interpreter for WHILE++ 
=====================================

Previously, you wrote a simple interpreter for *WHILE*.
For this problem, you will use monad transformers to build
an evaluator for *WHILE++* which, adds exceptions and I/O 
to the original language.

As before, we have variables, and expressions.

> type Variable = String
> type Store    = Map Variable Value
>
> data Value =
>     IntVal Int
>   | BoolVal Bool
>   deriving (Show)
>
> data Expression =
>     Var Variable
>   | Val Value  
>   | Op  Bop Expression Expression
>   deriving (Show)
>
> data Bop = 
>     Plus     
>   | Minus    
>   | Times    
>   | Divide   
>   | Gt        
>   | Ge       
>   | Lt       
>   | Le       
>   deriving (Show)

Programs in the language are simply values of the type

> data Statement =
>     Assign Variable Expression          
>   | If Expression Statement Statement
>   | While Expression Statement       
>   | Sequence Statement Statement        
>   | Skip
>   | Print String Expression
>   | Throw Expression
>   | Try Statement Variable Statement
>   deriving (Show)

The only new constructs are the `Print`, `Throw` and the `Try` statements. 

- `Print s e` should print out (eg to stdout) log the string corresponding 
  to the string `s` followed by whatever `e` evaluates to, followed by a
  newline --- for example, `Print "Three: " (IntVal 3)' should display
  "Three: IntVal 3\n",

- `Throw e` evaluates the expression `e` and throws it as an exception, and

- `Try s x h` executes the statement `s` and if in the course of
  execution, an exception is thrown, then the exception comes shooting 
  up and is assigned to the variable `x` after which the *handler*
  statement `h` is executed.

We will use the `State` [monad][2] to represent the world-transformer.
Intuitively, `State s a` is equivalent to the world-transformer 
`s -> (a, s)`. See the above documentation for more details. 
You can ignore the bits about `StateT` for now.

> evalE2 :: Expression -> ErrorT Value (State Store) Value
> evalE2 = evalE

> evalE :: (MonadState Store m, MonadError Value m) => Expression -> m Value
> evalE (Var x)      =  do s <- get
>                          if member x s == True
>                            then return (s ! x)
>                            else return (IntVal 0)
>
> evalE (Val v)      = return v
>
> evalE (Op o e1 e2) = do
>  s <- get
>  x <- evalE e1
>  y <- evalE e2
>  case o of
>    Plus -> case x of
>              IntVal x -> case y of
>                            IntVal y -> return (IntVal (x+y))
>                            BoolVal y -> return (IntVal 2)
>              BoolVal x -> return (IntVal 2)
>    Minus -> case x of
>              IntVal x -> case y of
>                            IntVal y -> return (IntVal (x-y))
>                            BoolVal y -> return (IntVal 2)
>              BoolVal x -> return (IntVal 2)
>    Times -> case x of
>              IntVal x -> case y of
>                            IntVal y -> return (IntVal (x*y))
>                            BoolVal y -> return (IntVal 2)
>              BoolVal x -> return (IntVal 2)
>    Divide -> case x of
>              IntVal x -> case y of
>                            IntVal y -> case IntVal y of
>                                          IntVal 0 -> return (IntVal 1)
>                                          IntVal _ -> return (IntVal (x `div` y))
>                            BoolVal y -> return (IntVal 2)
>              BoolVal x -> return (IntVal 2)
>    Gt -> case x of
>              IntVal x -> case y of
>                            IntVal y -> return (BoolVal (x>y))
>                            BoolVal y -> return (IntVal 2)
>              BoolVal x -> return (IntVal 2)
>    Ge ->  case x of
>              IntVal x -> case y of
>                            IntVal y -> return (BoolVal (x>=y))
>                            BoolVal y -> return (IntVal 2)
>              BoolVal x -> return (IntVal 2)
>    Lt ->  case x of
>              IntVal x -> case y of
>                            IntVal y -> return (BoolVal (x<y))
>                            BoolVal y -> return (IntVal 2)
>              BoolVal x -> return (IntVal 2)
>    Le ->  case x of
>              IntVal x -> case y of
>                            IntVal y -> return (BoolVal (x<=y))
>                            BoolVal y -> return (IntVal 2)
>              BoolVal x -> return (IntVal 2)

> instance Error Value   where
>   noMsg =  IntVal 0

> evalESW :: Statement -> ErrorT Value (StateT Store (Writer String)) ()
> evalESW = evalS

Use monad transformers to write a function

> evalS :: (MonadState Store m, MonadError Value m, MonadWriter String m) => Statement -> m ()
> evalS w@(While e s)    = do
>   state <- get
>   let (res, st) = (runState( runErrorT (evalE2 e)) state  )
>   case res of
>      Right v -> case v of
>                   BoolVal True  -> evalS (Sequence s w)
>                   BoolVal False -> evalS Skip
>
> evalS Skip             = do { s <- get;
>                               put s }
>
> evalS (Sequence s1 s2) = evalS s1 >> evalS s2
>
> evalS (Assign x e )    = do { s <- get;
>                               value <- evalE e;
>                               put $ insert x value s }
>
> evalS (If e s1 s2)     = do { state <- get;
>                               value <- evalE e;
>                               case value of
>                                 BoolVal True  -> evalS s1;
>                                 BoolVal False -> evalS s2;
>                                 IntVal x      -> evalS Skip }
>
> evalS (Print s e)     = do { state <- get;
>                              value <- evalE e;
>                              tell $ s ++ show value ++ "\n";
>                              put state}
> evalS (Throw e)       = do { state <- get;
>                              value <- evalE e;
>                              throwError $ value;
>                              put state}
>
> evalS (Try s x h)     = do
>   evalS s
>   `catchError` (\error -> evalS (Sequence (Assign x (Val error)) h ) )

and use the above function to implement a second function

> execute :: Store -> Statement -> (Store, Maybe Value, String)
> execute store stmt = (store', maybeErr, log)
>     where ((err, store'), log) = runWriter (runStateT (runErrorT (evalESW stmt)) store)
>           maybeErr = case err of
>                           Left e  -> Just e
>                           Right v -> Nothing

such that `execute st s` returns a triple `(st', exn, log)` where 

- `st'` is the output state, 
- `exn` is possibly an exception (if the program terminates with an uncaught exception), 
- `log` is the log of messages generated by the `Print` statements.

Requirements
------------

In the case of exceptional termination, the `st'` should be the state *at
the point where the last exception was thrown, and `log` should include all
the messages *upto* that point -- make sure you stack your transformers
appropriately! 

- Reading an undefined variable should raise an exception carrying the value `IntVal 0`.

- Division by zero should raise an exception carrying the value `IntVal 1`.

- A run-time type error (addition of an integer to a boolean, comparison of
  two values of different types) should raise an exception carrying the value
  `IntVal 2`.

Example 1
---------

If `st` is the empty state (all variables undefined) and `s` is the program

~~~~~{.haskell}
X := 0 ;
Y := 1 ;
print "hello world: " X;
if X < Y then
  throw (X+Y)
else 
  skip
endif;
Z := 3 
~~~~~

then `execute st s` should return the triple 

~~~~~{.haskell}
(fromList [("X", IntVal 0), ("Y",  IntVal 1)], Just (IntVal 1), "hello world: IntVal 0\n")
~~~~~

The program is provided as a Haskell value below:

> mksequence = foldr Sequence Skip

> testprog1 = mksequence [Assign "X" $ Val $ IntVal 0,
>                         Assign "Y" $ Val $ IntVal 1,
>                         Print "hello world: " $ Var "X",
>                         If (Op Lt (Var "X") (Var "Y")) (Throw (Op Plus (Var "X") (Var "Y")))
>                                                        Skip,
>                         Assign "Z" $ Val $ IntVal 3]

Example 2
---------

If `st` is the empty state (all variables undefined) and `s` is the program

~~~~~{.haskell}
X := 0 ;
Y := 1 ;
try  
  if X < Y then
    A := 100;
    throw (X+Y);
    B := 200
  else 
    skip
  endif;
catch E with
  Z := E + A
endwith
~~~~~

then `execute st s` should return the triple 

~~~~~{.haskell}
( fromList [("A", IntVal 100), ("E", IntVal 1)
           ,("X", IntVal 0), ("Y", IntVal 1)
 	   ,("Z", IntVal 101)]
, Nothing 
, "")
~~~~~

Again, the program as a Haskell value:

> testprog2 = mksequence [Assign "X" $ Val $ IntVal 0,
>                         Assign "Y" $ Val $ IntVal 1,
>                         Try (If (Op Lt (Var "X") (Var "Y"))
>                                 (mksequence [Assign "A" $ Val $ IntVal 100,
>                                              Throw (Op Plus (Var "X") (Var "Y")),
>                                              Assign "B" $ Val $ IntVal 200])
>                                 Skip)
>                             "E"
>                             (Assign "Z" $ Op Plus (Var "E") (Var "A"))]


Problem 2: Circuit Testing
==========================

Credit: [UPenn CIS552][1]

For this problem, you will look at a model of circuits in Haskell.

Signals
-------

A *signal* is a list of booleans.  

> newtype Signal = Sig [Bool]

By convention, all signals are infinite. We write a bunch of lifting
functions that lift boolean operators over signals.

> lift0 ::  Bool -> Signal
> lift0 a = Sig $ repeat a
> 
> lift1 ::  (Bool -> Bool) -> Signal -> Signal
> lift1 f (Sig s) = Sig $ map f s
> 
> lift2 ::  (Bool -> Bool -> Bool) -> (Signal, Signal) -> Signal
> lift2 f (Sig xs, Sig ys) = Sig $ zipWith f xs ys
> 
> lift22 :: (Bool -> Bool -> (Bool, Bool)) -> (Signal, Signal) -> (Signal,Signal)
> lift22 f (Sig xs, Sig ys) = 
>   let (zs1,zs2) = unzip (zipWith f xs ys)
>   in (Sig zs1, Sig zs2) 
> 
> lift3 :: (Bool->Bool->Bool->Bool) -> (Signal, Signal, Signal) -> Signal
> lift3 f (Sig xs, Sig ys, Sig zs) = Sig $ zipWith3 f xs ys zs
> 

Simulation
----------

Next, we have some helpers that can help us simulate a circuit by showing
how it behaves over time. For testing or printing, we truncate a signal to 
a short prefix 

> truncatedSignalSize = 20
> truncateSig bs = take truncatedSignalSize bs
> 
> instance Show Signal where
>   show (Sig s) = show (truncateSig s) ++ "..."
> 
> trace :: [(String, Signal)] -> Int -> IO ()
> trace desc count = do 
>   putStrLn   $ intercalate " " names
>   forM_ rows $ putStrLn . intercalate " " . rowS
>   where (names, wires) = unzip desc
>         rows           = take count . transpose . map (\ (Sig w) -> w) $ wires
>         rowS bs        = zipWith (\n b -> replicate (length n - 1) ' ' ++ (show (binary b))) names bs
> 
> probe :: [(String,Signal)] -> IO ()
> probe desc = trace desc 1
> 
> simulate :: [(String, Signal)] -> IO ()
> simulate desc = trace desc 20

Testing support (QuickCheck helpers)
------------------------------------

Next, we have a few functions that help to generate random tests

> instance Arbitrary Signal where
>   arbitrary = do 
>     x      <- arbitrary
>     Sig xs <- arbitrary
>     return $ Sig (x : xs)
> 
> arbitraryListOfSize n = forM [1..n] $ \_ -> arbitrary

To check whether two values are equivalent 

> class Agreeable a where
>   (===) :: a -> a -> Bool
> 
> instance Agreeable Signal where
>   (Sig as) === (Sig bs) = 
>     all (\x->x) (zipWith (==) (truncateSig as) (truncateSig bs))
> 
> instance (Agreeable a, Agreeable b) => Agreeable (a,b) where
>   (a1,b1) === (a2,b2) = (a1 === a2) && (b1 === b2)
> 
> instance Agreeable a => Agreeable [a] where
>   as === bs = all (\x->x) (zipWith (===) as bs)
> 

To convert values from boolean to higher-level integers

> class Binary a where
>   binary :: a -> Integer
> 
> instance Binary Bool where
>   binary b = if b then 1 else 0
> 
> instance Binary [Bool] where
>   binary = foldr (\x r -> (binary x) + 2 *r) 0

And to probe signals at specific points.

> sampleAt n (Sig b) = b !! n
> sampleAtN n signals = map (sampleAt n) signals
> sample1 = sampleAt 0
> sampleN = sampleAtN 0


Basic Gates
-----------

The basic gates from which we will fashion circuits can now be described.

> or2 ::  (Signal, Signal) -> Signal
> or2 = lift2 $ \x y -> x || y 
> 
> xor2 :: (Signal, Signal) -> Signal
> xor2 = lift2 $ \x y -> (x && not y) || (not x && y)
> 
> and2 :: (Signal, Signal) -> Signal
> and2 = lift2 $ \x y -> x && y 
> 
> imp2 ::  (Signal, Signal) -> Signal
> imp2 = lift2 $ \x y -> (not x) || y 
>
> mux :: (Signal, Signal, Signal) -> Signal
> mux = lift3 (\b1 b2 select -> if select then b1 else b2)
>
> demux :: (Signal, Signal) -> (Signal, Signal)
> demux args = lift22 (\i select -> if select then (i, False) else (False, i)) args
>
> muxN :: ([Signal], [Signal], Signal) -> [Signal]
> muxN (b1,b2,sel) = map (\ (bb1,bb2) -> mux (bb1,bb2,sel)) (zip b1 b2)
>
> demuxN :: ([Signal], Signal) -> ([Signal], [Signal])
> demuxN (b,sel) = unzip (map (\bb -> demux (bb,sel)) b)


Basic Signals 
-------------

Similarly, here are some basic signals

> high = lift0 True
> low  = lift0 False
>
> str   ::  String -> Signal
> str cs = Sig $ (map (== '1') cs) ++ (repeat False)
>
> delay ::  Bool -> Signal -> Signal
> delay init (Sig xs) = Sig $ init : xs


Combinational circuits
----------------------

**NOTE** When you are asked to implement a circuit, you must **ONLY** use
the above gates or smaller circuits built from the gates.

For example, the following is a *half-adder* (that adds a carry-bit to a
single bit).

> halfadd :: (Signal, Signal) -> (Signal, Signal)
> halfadd (x,y) = (sum,cout)
>   where sum   = xor2 (x, y)
>         cout  = and2 (x, y)

Here is a simple property about the half-adder

> prop_halfadd_commut b1 b2 =
>   halfadd (lift0 b1, lift0 b2) === halfadd (lift0 b2, lift0 b1) 

We can use the half-adder to build a full-adder

> fulladd (cin, x, y) = (sum, cout)
>   where (sum1, c1)  = halfadd (x,y)
>         (sum, c2)   = halfadd (cin, sum1)
>         cout        = xor2 (c1,c2) 
> 
> test1a = probe [("cin",cin), ("x",x), ("y",y), ("  sum",sum), ("cout",cout)]
>   where cin        = high
>         x          = low
>         y          = high
>         (sum,cout) = fulladd (cin, x, y)

and then an n-bit adder

> bitAdder :: (Signal, [Signal]) -> ([Signal], Signal)
> bitAdder (cin, [])   = ([], cin)
> bitAdder (cin, x:xs) = (sum:sums, cout)
>   where (sum, c)     = halfadd (cin,x)
>         (sums, cout) = bitAdder (c,xs)
> 
> test1 = probe [("cin",cin), ("in1",in1), ("in2",in2), ("in3",in3), ("in4",in4),
>                ("  s1",s1), ("s2",s2), ("s3",s3), ("s4",s4), ("c",c)]
>   where
>     cin = high
>     in1 = high
>     in2 = high
>     in3 = low
>     in4 = high
>     ([s1,s2,s3,s4], c) = bitAdder (cin, [in1,in2,in3,in4])

The correctness of the above circuit is described by the following property
that compares the behavior of the circuit to the *reference implementation*
which is an integer addition function

> prop_bitAdder_Correct ::  Signal -> [Bool] -> Bool
> prop_bitAdder_Correct cin xs =
>   binary (sampleN out ++ [sample1 cout]) == binary xs + binary (sample1 cin)
>   where (out, cout) = bitAdder (cin, map lift0 xs) 
 
Finally, we can use the bit-adder to build an adder that adds two N-bit numbers

> adder :: ([Signal], [Signal]) -> [Signal]
> adder (xs, ys) = 
>    let (sums,cout) = adderAux (low, xs, ys)
>    in sums ++ [cout]
>    where                                        
>      adderAux (cin, [], [])     = ([], cin)
>      adderAux (cin, x:xs, y:ys) = (sum:sums, cout)
>                                   where (sum, c) = fulladd (cin,x,y)
>                                         (sums,cout) = adderAux (c,xs,ys)
>      adderAux (cin, [], ys)     = adderAux (cin, [low], ys)
>      adderAux (cin, xs, [])     = adderAux (cin, xs, [low])
> 
> test2 = probe [ ("x1", x1), ("x2",x2), ("x3",x3), ("x4",x4),
>                 (" y1",y1), ("y2",y2), ("y3",y3), ("y4",y4), 
>                 (" s1",s1), ("s2",s2), ("s3",s3), ("s4",s4), (" c",c) ]
>   where xs@[x1,x2,x3,x4] = [high,high,low,low]
>         ys@[y1,y2,y3,y4] = [high,low,low,low]
>         [s1,s2,s3,s4,c]  = adder (xs, ys)

And we can specify the correctness of the adder circuit by

> prop_Adder_Correct ::  [Bool] -> [Bool] -> Bool
> prop_Adder_Correct l1 l2 = 
>   binary (sampleN sum) == binary l1 + binary l2
>   where sum = adder (map lift0 l1, map lift0 l2) 

Problem: Subtraction
--------------------

1. Using `prop_bitAdder_Correct` as a model, write a speciﬁcation for a
single-bit subtraction function that takes as inputs a N-bit binary 
number and a single bit to be subtracted from it and yields as
outputs an N-bit binary number. Subtracting one from zero should
yield zero.

> prop_bitSubtractor_Correct ::  Signal -> [Bool] -> Bool
> prop_bitSubtractor_Correct bitsub xs = case (binary xs - binary (sample1 bitsub)) of
>                       -1      -> (binary (sampleN out) == 0)
>                       x       -> (binary (sampleN out) == x)
>     where (out, bout)   = bitSubtractor (bitsub, map lift0 xs)

2. Using the `bitAdder` circuit as a model, deﬁne a `bitSubtractor` 
circuit that implements this functionality and use QC to check that 
your behaves correctly.

> bitSubtractor :: (Signal, [Signal]) -> ([Signal], Signal)
> bitSubtractor (borrow, []) = ([], borrow)
> bitSubtractor (borrow, x:xs) =
>   if ((binary $ map sample1 (x:xs)) == 0) then ([low], borrow)
>                                         else (sub:subs, bout)
>                                         where (sub, b)     = halfsub (x, borrow)
>                                               (subs, bout) = bitSubtractor (b,xs)

> halfsub :: (Signal, Signal) -> (Signal, Signal)
> halfsub (x,y) = (diff, borrow)
>   where diff          = xor2 (x, y)
>         borrow        = and2 (xor2 (x, y), imp2 (x, y))

Problem: Multiplication
-----------------------

3. Using `prop_Adder_Correct` as a model, write down a QC speciﬁcation 
for a `multiplier` circuit that takes two binary numbers of arbitrary 
width as input and outputs their product.

> prop_Multiplier_Correct ::  [Bool] -> [Bool] -> Bool
> prop_Multiplier_Correct l1 l2 =
>   binary (sampleN prod) == binary l1 * binary l2
>   where prod = multiplier (map lift0 l1, map lift0 l2)

4. Deﬁne a `multiplier` circuit and check that it satisﬁes your 
speciﬁcation. (Looking at how adder is deﬁned will help with this, 
but you’ll need a little more wiring. To get an idea of how the 
recursive structure should work, think about how to multiply two 
binary numbers on paper.)

> multiplier :: ([Signal], [Signal]) -> [Signal]
> multiplier (xs, []) = []
> multiplier (xs, a:[]) = case (binary (sample1 a)) of
>                                                       1       ->      xs
>                                                       0       ->      [low]
> multiplier (xs, y:ys) = adder (multiplier (xs, [y]), shiftRight (multiplier (xs, ys)))
>       where   shiftRight xs   =       low:xs

[1]: http://www.cis.upenn.edu/~bcpierce/courses/552-2008/resources/circuits.hs


