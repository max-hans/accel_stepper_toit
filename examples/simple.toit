
import ..src.accel-stepper


main:
  stepper := AccelStepper MotorInterfaceType.FULL2WIRE [2,3,4] true
  stepper.set-max-speed 100.0
  stepper.set-acceleration 20.0
  stepper.move-to 500
  while true:
    if stepper.get-distance-to-go == 0:
      stepper.move-to -stepper.get-current-position
    stepper.run