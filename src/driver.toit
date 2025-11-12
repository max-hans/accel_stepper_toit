import math
import .math-utils as mu

import .types show MotorInterfaceType Direction
import gpio

class AccelStepper:

    
  _stepper_interface /int := ?  
  _pins /List := ?
  _pin-inverted /List := []
  _current-pos /int := 0
  _target-pos /int := ? 
  _speed /float := ?  
  _max-speed /float := ? 
  _acceleration /float := ? 
  _sqrt-twoa /float := ?  
  _last-step-time /int := ?  
  _step-interval /int := ?
  _min-pulse-width /int := ? 
  _enable-inverted /bool := ?  
  _enable-pin /int := ?  
  
  _n /int := ? 
  _c0 /float := ? 
  _cn /float := ? 
  _cmin /float := ? 

  _direction /int := ?
  /* (*_forward)() /void := ?  
  (*_backward)() /void := ?  */
  
  constructor stepper_interface/int  pins/List  enable/bool = true:

    _stepper_interface = stepper_interface
    _current_pos = 0
    _target_pos = 0
    _speed = 0.0
    _max-speed = 0.0
    _acceleration = 0.0
    _sqrt_twoa = 1.0
    _step-interval = 0
    _min-pulse-width = 1
    _enable-pin = 0xff 
    _last-step-time = 0
    _enable-inverted = false

    _pins = pins.map: |pin-num|
      continue.map (gpio.Pin pin-num)

    _pin-inverted = pins.map:
      continue.map false
    
    _n = 0
    _c0 = 0.0
    _cn = 0.0
    _cmin = 1.0
    _direction = Direction.DIRECTION_CCW
  
  move_to position/int  -> none:

  move relative_position/int -> none:

  set-max-speed speed/int -> none:
  set-speed speed/int -> none:
    if speed == _speed: return;
    new-speed/float := mu.constrain speed.to-float -_max-speed _max-speed

    if new-speed == 0.0:
      _step-interval = 0
    else:
      _step-interval = mu.fabs ( 1000000.0 / new-speed )
      _direction = new-speed > 0.0 ? Direction.DIRECTION-CW : Direction.DIRECTION-CCW
    _speed = new-speed

  get-speed -> int:
    return -1
  
  set-acceleration acceleration/float:
    if (acceleration == 0.0):	  return
    if (acceleration < 0.0): acceleration = -acceleration
    if (_acceleration != acceleration):
      _n = (_n * (_acceleration / acceleration)).to-int
      // New c0 per Equation 7, with correction per Equation 15
      _c0 = 0.676 * ( math.sqrt 2.0 / acceleration) * 1000000.0
      _acceleration = acceleration;
      compute-new-speed
  
  get-acceleration -> float:
    return _acceleration

  get-position -> int:
    return -1

  get-distance-to-go -> int:
    return -1

  set-output-pins mask/int:
    _pins.size.repeat: |index|
      pin := _pins[index]
      pin-is-inverted := _pin-inverted[index]
      value-to-write := (mask & (1 << index)) == 1 ? (1 ^ pin-is-inverted) : (0 ^ pin-is-inverted)


  step1 step/int:
    // _pin[0] is step, _pin[1] is direction
    if _direction == Direction.DIRECTION-CW:
      set-output-pins  0b10 
    else:
      set-output-pins 0b00
    
    
    if _direction == Direction.DIRECTION-CW:
      set-output-pins  0b11 
    else:
      set-output-pins 0b01
    
    duration := Duration --us=_min-pulse-width
    sleep duration

    if _direction == Direction.DIRECTION-CW:  set-output-pins  0b10
    else:  set-output-pins 0b00 

  step2 step/int:
    condition := step & 0x3

    if condition == 0:
      set-output-pins 0b10
      return

    if condition == 1: /* 11 */
      set-output-pins 0b11
      return

    if condition == 2: /* 10 */
      set-output-pins 0b01
      return

    if condition == 3: /* 00 */
      set-output-pins 0b00
      return
  
  step3 step/int:
    condition := step % 3

    if condition == 0:
      set-output-pins 0b100
      return

    if condition == 1: /* 11 */
      set-output-pins 0b001
      return

    if condition == 2: /* 10 */
      set-output-pins 0b010
      return
  
  step4 step/int:
    condition := step & 0x3

    if condition == 0:
      set-output-pins 0b0101
      return

    if condition == 1:
      set-output-pins 0b0110
      return

    if condition == 2:
      set-output-pins 0b1010
      return

    if condition == 3:
      set-output-pins 0b1001
      return

  step6 step/int:
    condition := step % 6
    if condition == 0:    // 100
      set-output-pins 0b100
      return

    if condition == 1:    // 101
      set-output-pins 0b101
      return

    if condition == 2:    // 001
      set-output-pins 0b001
      return

    if condition == 3:    // 011
      set-output-pins 0b011
      return

    if condition == 4:    // 010
      set-output-pins 0b010
      return

    if condition == 5:    // 011
      set-output-pins 0b110
      return
  
  step8 step/int:
    condition := step & 0x7
    if condition == 0:    // 1000
      set-output-pins 0b0001
      return

    if condition == 1:    // 1010
      set-output-pins 0b0101
      return

    if condition == 2:    // 0010
      set-output-pins 0b0100
      return

    if condition == 3:    // 0110
      set-output-pins 0b0110
      return

    if condition == 4:    // 0100
      set-output-pins 0b0010
      return

    if condition == 5:    //0101
      set-output-pins 0b1010
      return

    if condition == 6:    // 0001
      set-output-pins 0b1000
      return

    if condition == 7:    //1001
      set-output-pins 0b1001
      return

  disable-outputs:
    if _stepper-interface == 0:
      return
    set-output-pins 0

    if _enable-pin and _enable-pin != 0xff:
      enable_pin := gpio.Pin _enable-pin --output
      // todo: this can be made better?
      enable-inverted-int := _enable-inverted ? 1 : 0
      enable_pin.set 0 ^ enable-inverted-int


  compute-new-speed -> none:
    distance-to /int := get-distance-to-go

    steps-to-stop /int  := (_speed * _speed / 2.0 * _acceleration).to-int

    if distance-to == 0 and steps-to-stop <= 1:
      // We are at the target and its time to stop
      _step-interval = 0;
      _speed = 0.0;
      _n = 0;

    if (distance-to > 0):
      // We are anticlockwise from the target
      // Need to go clockwise from here, maybe decelerate now
      if (_n > 0):
      
          // Currently accelerating, need to decel now? Or maybe going the wrong way?
          if ((steps-to-stop >= distance-to) or _direction == Direction.DIRECTION_CCW):
            _n = -steps-to-stop; // Start deceleration
      else if (_n < 0):
          // Currently decelerating, need to accel again?
          if ((steps-to-stop < distance-to) and _direction == Direction.DIRECTION_CW):
            _n = -_n; // Start accceleration
    else if (distance-to < 0):
    
      // We are clockwise from the target
      // Need to go anticlockwise from here, maybe decelerate
      if (_n > 0):
          // Currently accelerating, need to decel now? Or maybe going the wrong way?
           // Start deceleration
          if ((steps-to-stop >= -distance-to) or _direction == Direction.DIRECTION_CW):_n = -steps-to-stop.to-int;
            
      else if (_n < 0):
          // Currently decelerating, need to accel again?
          if ((steps-to-stop < -distance-to) and _direction == Direction.DIRECTION_CCW): _n = -_n; 
            

    // Need to accelerate or decelerate
    if (_n == 0):
      // First step from stopped
      _cn = _c0;
      _direction = (distance-to > 0) ? Direction.DIRECTION_CW : Direction.DIRECTION_CCW;
    else:
      // Subsequent step. Works for accel (n is +_ve) and decel (n is -ve).
      _cn = _cn - ((2.0 * _cn) / ((4.0 * _n) + 1)); // Equation 13
      _cn = (mu.max-val _cn _cmin).to-float
    _n++;
    _step-interval = _cn.to-int;
    _speed = 1000000.0 / _cn;
    if (_direction == Direction.DIRECTION_CCW):
      _speed = -_speed;
