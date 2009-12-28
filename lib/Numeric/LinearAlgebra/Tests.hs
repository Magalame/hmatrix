{-# LANGUAGE CPP #-}
{-# OPTIONS_GHC -fno-warn-unused-imports -fno-warn-incomplete-patterns #-}
-----------------------------------------------------------------------------
{- |
Module      :  Numeric.LinearAlgebra.Tests
Copyright   :  (c) Alberto Ruiz 2007-9
License     :  GPL-style

Maintainer  :  Alberto Ruiz (aruiz at um dot es)
Stability   :  provisional
Portability :  portable

Some tests.

-}

module Numeric.LinearAlgebra.Tests(
--  module Numeric.LinearAlgebra.Tests.Instances,
--  module Numeric.LinearAlgebra.Tests.Properties,
  qCheck, runTests
--, runBigTests
) where

import Numeric.LinearAlgebra
import Numeric.LinearAlgebra.LAPACK
import Numeric.LinearAlgebra.Tests.Instances
import Numeric.LinearAlgebra.Tests.Properties
import Test.HUnit hiding ((~:),test,Testable)
import System.Info
import Data.List(foldl1')
import Numeric.GSL hiding (sin,cos,exp,choose)
import Prelude hiding ((^))
import qualified Prelude
#include "Tests/quickCheckCompat.h"

a ^ b = a Prelude.^ (b :: Int)

utest str b = TestCase $ assertBool str b

a ~~ b = fromList a |~| fromList b

feye n = flipud (ident n) :: Matrix Double

detTest1 = det m == 26
        && det mc == 38 :+ (-3)
        && det (feye 2) == -1
    where
        m = (3><3) 
            [ 1, 2, 3
            , 4, 5, 7
            , 2, 8, 4 :: Double
            ]
        mc = (3><3)
            [ 1, 2, 3
            , 4, 5, 7
            , 2, 8, i
            ]

--------------------------------------------------------------------

polyEval cs x = foldr (\c ac->ac*x+c) 0 cs

polySolveProp p = length p <2 || last p == 0|| 1E-8 > maximum (map magnitude $ map (polyEval (map (:+0) p)) (polySolve p))

---------------------------------------------------------------------

quad f a b = fst $ integrateQAGS 1E-9 100 f a b

-- A multiple integral can be easily defined using partial application
quad2 f a b g1 g2 = quad h a b
    where h x = quad (f x) (g1 x) (g2 x)

volSphere r = 8 * quad2 (\x y -> sqrt (r*r-x*x-y*y)) 
                        0 r (const 0) (\x->sqrt (r*r-x*x))

---------------------------------------------------------------------

besselTest = utest "bessel_J0_e" ( abs (r-expected) < e )
    where (r,e) = bessel_J0_e 5.0
          expected = -0.17759677131433830434739701

exponentialTest = utest "exp_e10_e" ( abs (v*10^e - expected) < 4E-2 )
    where (v,e,_err) = exp_e10_e 30.0
          expected = exp 30.0

---------------------------------------------------------------------

nd1 = (3><3) [ 1/2, 1/4, 1/4
             , 0/1, 1/2, 1/4
             , 1/2, 1/4, 1/2 :: Double]

nd2 = (2><2) [1, 0, 1, 1:: Complex Double]

expmTest1 = expm nd1 :~14~: (3><3)
 [ 1.762110887278176
 , 0.478085470590435
 , 0.478085470590435
 , 0.104719410945666
 , 1.709751181805343
 , 0.425725765117601
 , 0.851451530235203
 , 0.530445176063267
 , 1.814470592751009 ]

expmTest2 = expm nd2 :~15~: (2><2)
 [ 2.718281828459045
 , 0.000000000000000
 , 2.718281828459045
 , 2.718281828459045 ]

---------------------------------------------------------------------

minimizationTest = TestList
    [ utest "minimization conjugatefr" (minim1 f df [5,7] ~~ [1,2])
    , utest "minimization nmsimplex2"  (minim2 f [5,7] `elem` [24,25])
    ]
    where f [x,y] = 10*(x-1)^2 + 20*(y-2)^2 + 30
          df [x,y] = [20*(x-1), 40*(y-2)]
          minim1 g dg ini = fst $ minimizeD ConjugateFR 1E-3 30 1E-2 1E-4 g dg ini
          minim2 g ini = rows $ snd $ minimize NMSimplex2 1E-2 30 [1,1] g ini

---------------------------------------------------------------------

rootFindingTest = TestList [ utest "root Hybrids" (fst sol1 ~~ [1,1])
                           , utest "root Newton"  (rows (snd sol2) == 2)
                           ]
    where sol1 = root Hybrids 1E-7 30 (rosenbrock 1 10) [-10,-5]
          sol2 = rootJ Newton 1E-7 30 (rosenbrock 1 10) (jacobian 1 10) [-10,-5]
          rosenbrock a b [x,y] = [ a*(1-x), b*(y-x^2) ]
          jacobian a b [x,_y] = [ [-a    , 0]
                                , [-2*b*x, b] ]

---------------------------------------------------------------------

randomTestGaussian = c :~1~: snd (meanCov dat) where
    a = (3><3) [1,2,3,
                2,4,0,
               -2,2,1]
    m = 3 |> [1,2,3]
    c = a <> trans a
    dat = gaussianSample 7 (10^6) m c

randomTestUniform = c :~1~: snd (meanCov dat) where
    c = diag $ 3 |> map ((/12).(^2)) [1,2,3]
    dat = uniformSample 7 (10^6) [(0,1),(1,3),(3,6)]

---------------------------------------------------------------------

rot :: Double -> Matrix Double
rot a = (3><3) [ c,0,s
               , 0,1,0
               ,-s,0,c ]
    where c = cos a
          s = sin a

rotTest = fun (10^5) :~12~: rot 5E4
    where fun n = foldl1' (<>) (map rot angles)
              where angles = toList $ linspace n (0,1)

-- | All tests must pass with a maximum dimension of about 20
--  (some tests may fail with bigger sizes due to precision loss).
runTests :: Int  -- ^ maximum dimension
         -> IO ()
runTests n = do
    setErrorHandlerOff
    let test p = qCheck n p
    putStrLn "------ mult"
    test (multProp1  . rConsist)
    test (multProp1  . cConsist)
    test (multProp2  . rConsist)
    test (multProp2  . cConsist)
    putStrLn "------ lu"
    test (luProp    . rM)
    test (luProp    . cM)
    putStrLn "------ inv (linearSolve)"
    test (invProp   . rSqWC)
    test (invProp   . cSqWC)
    putStrLn "------ luSolve"
    test (linearSolveProp (luSolve.luPacked) . rSqWC)
    test (linearSolveProp (luSolve.luPacked) . cSqWC)
    putStrLn "------ pinv (linearSolveSVD)"
    test (pinvProp  . rM)
    test (pinvProp  . cM)
    putStrLn "------ det"
    test (detProp   . rSqWC)
    test (detProp   . cSqWC)
    putStrLn "------ svd"
    test (svdProp1  . rM)
    test (svdProp1  . cM)
    test (svdProp1a svdR)
    test (svdProp1a svdC)
    test (svdProp1a svdRd)
    test (svdProp1a svdCd)
    test (svdProp2 thinSVDR)
    test (svdProp2 thinSVDC)
    test (svdProp2 thinSVDRd)
    test (svdProp2 thinSVDCd)
    test (svdProp3  . rM)
    test (svdProp3  . cM)
    test (svdProp4  . rM)
    test (svdProp4  . cM)
    test (svdProp5a)
    test (svdProp5b)
    test (svdProp6a)
    test (svdProp6b)
    test (svdProp7  . rM)
    test (svdProp7  . cM)
    putStrLn "------ eig"
    test (eigSHProp . rHer)
    test (eigSHProp . cHer)
    test (eigProp   . rSq)
    test (eigProp   . cSq)
    test (eigSHProp2 . rHer)
    test (eigSHProp2 . cHer)
    test (eigProp2   . rSq)
    test (eigProp2   . cSq)
    putStrLn "------ nullSpace"
    test (nullspaceProp . rM)
    test (nullspaceProp . cM)
    putStrLn "------ qr"
    test (qrProp     . rM)
    test (qrProp     . cM)
    putStrLn "------ hess"
    test (hessProp   . rSq)
    test (hessProp   . cSq)
    putStrLn "------ schur"
    test (schurProp2 . rSq)
    test (schurProp1 . cSq)
    putStrLn "------ chol"
    test (cholProp   . rPosDef)
    test (cholProp   . cPosDef)
    putStrLn "------ expm"
    test (expmDiagProp . rSqWC)
    test (expmDiagProp . cSqWC)
    putStrLn "------ fft"
    test (\v -> ifft (fft v) |~| v)
    putStrLn "------ vector operations"
    test (\u -> sin u ^ 2 + cos u ^ 2 |~| (1::RM))
    test $ (\u -> sin u ^ 2 + cos u ^ 2 |~| (1::CM)) . liftMatrix makeUnitary
    test (\u -> sin u ** 2 + cos u ** 2 |~| (1::RM))
    test (\u -> cos u * tan u |~| sin (u::RM))
    test $ (\u -> cos u * tan u |~| sin (u::CM)) . liftMatrix makeUnitary
    putStrLn "------ read . show"
    test (\m -> (m::RM) == read (show m))
    test (\m -> (m::CM) == read (show m))
    test (\m -> toRows (m::RM) == read (show (toRows m)))
    test (\m -> toRows (m::CM) == read (show (toRows m)))
    putStrLn "------ some unit tests"
    _ <- runTestTT $ TestList
        [ utest "1E5 rots" rotTest
        , utest "det1" detTest1
        , utest "expm1" (expmTest1)
        , utest "expm2" (expmTest2)
        , utest "arith1" $ ((ones (100,100) * 5 + 2)/0.5 - 7)**2 |~| (49 :: RM)
        , utest "arith2" $ (((1+i) .* ones (100,100) * 5 + 2)/0.5 - 7)**2 |~| ( (140*i-51).*1 :: CM)
        , utest "arith3" $ exp (i.*ones(10,10)*pi) + 1 |~| 0
        , utest "<\\>"   $ (3><2) [2,0,0,3,1,1::Double] <\> 3|>[4,9,5] |~| 2|>[2,3]
        , utest "gamma" (gamma 5 == 24.0)
        , besselTest
        , exponentialTest
        , utest "integrate" (abs (volSphere 2.5 - 4/3*pi*2.5^3) < 1E-8)
        , utest "polySolve" (polySolveProp [1,2,3,4])
        , minimizationTest
        , rootFindingTest
        , utest "randomGaussian" randomTestGaussian
        , utest "randomUniform" randomTestUniform
        , utest "buildVector/Matrix" $
                        comp (10 |> [0::Double ..]) == buildVector 10 fromIntegral
                     && ident 5 == buildMatrix 5 5 (\(r,c) -> if r==c then 1::Double else 0)
        , utest "rank" $  rank ((2><3)[1,0,0,1,6*eps,0]) == 1
                       && rank ((2><3)[1,0,0,1,7*eps,0]) == 2
        ]
    return ()

makeUnitary v | realPart n > 1    = v */ n
              | otherwise = v
    where n = sqrt (conj v <.> v)

-- -- | Some additional tests on big matrices. They take a few minutes.
-- runBigTests :: IO ()
-- runBigTests = undefined
