class Direction:
  static DIRECTION_CCW ::= 0
  static DIRECTION_CW  ::= 1

class MotorInterfaceType:
  static FUNCTION  ::= 0 ///< Use the functional interface, implementing your own driver functions (internal use only)
  static DRIVER    ::= 1 ///< Stepper Driver, 2 driver pins required
  static FULL2WIRE ::= 2 ///< 2 wire stepper, 2 motor pins required
  static FULL3WIRE ::= 3 ///< 3 wire stepper, such as HDD spindle, 3 motor pins required
  static FULL4WIRE ::= 4 ///< 4 wire full stepper, 4 motor pins required
  static HALF3WIRE ::= 6 ///< 3 wire half stepper, such as HDD spindle, 3 motor pins required
  static HALF4WIRE ::= 8 ///< 4 wire half stepper, 4 motor pins required

