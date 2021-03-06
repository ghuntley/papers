{-# LANGUAGE CPP #-}
--
-- A stable fluid simulation
--
-- Jos Stam, "Real-time Fluid Dynamics for Games"
--

module Main where

import Config
import World
import Fluid
import Event
import Data.Label
import Criterion.Main                           ( defaultMainWith, bench, whnf )
import Control.Exception
import System.Environment
import Graphics.Gloss.Interface.IO.Game

import Prelude                                  as P
import Data.Array.Accelerate                    as A


main :: IO ()
main = do
  (opt,crit,noms) <- parseArgs =<< getArgs
  let -- configuration parameters
      --
      width     = get simulationWidth  opt * get displayScale opt
      height    = get simulationHeight opt * get displayScale opt
      steps     = get simulationSteps  opt
      fps       = get displayFramerate opt
      dp        = get viscosity opt
      dn        = get diffusion opt
      dt        = get timestep opt

      -- Prepare user-input density and velocity sources
      --
      sources s = let (ix, ss)  = P.unzip s
                      sh        = Z :. length ix
                  in  ( A.fromList sh ix, A.fromList sh ss )

      -- for benchmarking
      --
      force w   =
        indexArray (densityField  w) (Z:.0:.0) `seq`
        indexArray (velocityField w) (Z:.0:.0) `seq` w

      -- Prepare to execute the next step of the simulation.
      --
      -- Critically, we use the run1 execution form to ensure we bypass all
      -- front-end conversion phases.
      --
      maxSteps = 100
      simulate world
        | simulationStep world > maxSteps
        = world

        | otherwise
        = let step        = run1 opt (fluid steps dt dp dn)
              ds          = sources (densitySource world)
              vs          = sources (velocitySource world)
              (df', vf')  = step ( ds, vs, densityField world, velocityField world )
              n           = simulationStep world
          in
          simulate $ world { densityField  = df', velocityField  = vf'
                           , densitySource = [],  velocitySource = []
                           , simulationStep = 1 + n }

  initialWorld  <- evaluate (initialise opt)
  _             <- evaluate (simulate initialWorld)

  return ()

{--
#ifndef ACCELERATE_ENABLE_GUI
  if True
#else
  if get optBench opt
#endif
     -- benchmark
     then withArgs noms $ defaultMainWith crit (return ())
              [ bench "fluid" $ whnf simulate initialWorld ]

     -- simulate
     else playIO
              (InWindow "accelerate-fluid" (width, height) (10, 20))
              black                             -- background colour
              fps                               -- display framerate
              initialWorld                      -- initial state of the simulation
              (render opt)                      -- render world state into a picture
              (\e -> return . react opt e)      -- handle user events
              (\_ -> return . simulate)         -- one step of the simulation
--}

