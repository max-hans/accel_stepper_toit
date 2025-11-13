import math
import .math-utils as mu

import .types show MotorInterfaceType Direction
import gpio

class AccelStepper:

    
  _stepper_interface /MotorInterfaceType := ?  
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
  _enable-pin /gpio.Pin? := ?
  
  _n /int := ? 
  _c0 /float := ? 
  _cn /float := ? 
  _cmin /float := ? 

  

  _direction /int := ?
  
  constructor stepper_interface/MotorInterfaceType  pins/List  enable/bool = true:

    _stepper_interface = stepper_interface
    _current_pos = 0
    _target_pos = 0
    _speed = 0.0
    _max-speed = 0.0
    _acceleration = 0.0
    _sqrt_twoa = 1.0
    _step-interval = 0
    _min-pulse-width = 1
    _enable-pin = null
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

  set-max-speed speed/float -> none:
    new-speed := speed
    if new-speed < 0.0:
      new-speed = -new-speed
    if _max-speed != new-speed:
      _max-speed = new-speed
      _cmin = 1000000.0 / speed
      if _n > 0:
        _n = ((_speed * _speed) / (2.0 * _acceleration)).to-int

  get-max-speed:
    return _max-speed
  
  set-speed speed/int -> none:
    if speed == _speed: return;
    new-speed/float := mu.constrain speed.to-float -_max-speed _max-speed

    if new-speed == 0.0:
      _step-interval = 0
    else:
      _step-interval = mu.fabs ( 1000000.0 / new-speed )
      _direction = new-speed > 0.0 ? Direction.DIRECTION-CW : Direction.DIRECTION-CCW
    _speed = new-speed

  get-speed -> float:
    return _speed
  
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

  get-current-position -> int:
    return _current-pos
  
  set-current-position position/int -> none:
    _current-pos = position
    _target-pos = position
    _step-interval = 0
    _speed = 0.0

  get-distance-to-go -> int:
    return -1

  set-output-pins mask/int:
    _pins.size.repeat: |index|
      pin := _pins[index]
      pin-is-inverted := _pin-inverted[index]
      value-to-write := (mask & (1 << index)) == 1 ? (1 ^ pin-is-inverted) : (0 ^ pin-is-inverted)

  set-pins-inverted flags/List:
    if flags.size == 3 or flags.size == 4:
      // since the last one is the enable pin we need to get rid of that here
      step-pins := flags[..flags.size]
      _pin-inverted = step-pins.copy
      _enable-inverted = flags.last
    else:
      throw "Only available for drivers with 2 or 3 step pins"

  run:
    run-speed
    compute-new-speed
    return _speed != 0.0 or get-distance-to-go != 0

  run-speed:
    // Dont do anything unless we actually have a step interval
    if _step-interval == 0: return false

    time-us := Time.now.ns-since-epoch / 1000

    
    if (time-us - _last-step-time >= _step-interval):
      if _direction == Direction.DIRECTION-CW:
        _current-pos += 1
      else:
        _current-pos += -1
    step _current-pos

    _last-step-time = time-us
    return true 

  step step/int:

    if _stepper-interface ==  MotorInterfaceType.DRIVER:
      step1 step
      return

    if _stepper-interface ==  MotorInterfaceType.FULL2WIRE:
      step2 step
      return

    if _stepper-interface ==  MotorInterfaceType.FULL3WIRE:
      step3 step
      return

    if _stepper-interface ==  MotorInterfaceType.FULL4WIRE:
      step4 step
      return

    if _stepper-interface ==  MotorInterfaceType.HALF3WIRE:
      step6 step
      return

    if _stepper-interface ==  MotorInterfaceType.HALF4WIRE:
      step8 step
      return

  step1 step/int:
    // _pin[0] is step, _pin[1] is direction
    if _direction == Direction.DIRECTION-CW:
      set-output-pins 0b10 
    else:
      set-output-pins 0b00
    
    
    if _direction == Direction.DIRECTION-CW:
      set-output-pins 0b11 
    else:
      set-output-pins 0b01
    
    duration := Duration --us=_min-pulse-width
    sleep duration

    if _direction == Direction.DIRECTION-CW:  set-output-pins  0b10
    else: set-output-pins 0b00 

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


/*  if (! _interface) 
	return;

    pinMode(_pin[0], OUTPUT);
    pinMode(_pin[1], OUTPUT);
    if (_interface == FULL4WIRE || _interface == HALF4WIRE)
    {
        pinMode(_pin[2], OUTPUT);
        pinMode(_pin[3], OUTPUT);
    }
    else if (_interface == FULL3WIRE || _interface == HALF3WIRE)
    {
        pinMode(_pin[2], OUTPUT);
    }

    if (_enablePin != 0xff)
    {
        pinMode(_enablePin, OUTPUT);
        digitalWrite(_enablePin, HIGH ^ _enableInverted);
    } */
  /* enable-outputs:
    if _stepper-interface == 0:
      return
    
    _pins.do:
       */

  disable-outputs:
    if _stepper-interface == 0:
      return
    set-output-pins 0

    if _enable-pin != null and _enable-pin is gpio.Pin:
      _enable-pin.configure --output=true
      enable-inverted-int := _enable-inverted ? 1 : 0
      _enable-pin.set enable-inverted-int
  
  enable-outputs:
    if _stepper-interface == MotorInterfaceType.FUNCTION:
      return
    
    _pins.do:|pin|
      pin.configure --output=true

    if _enable-pin != null and _enable-pin is gpio.Pin:
      _enable-pin.configure --output=true
      enable-inverted-int := _enable-inverted ? 0 : 1
      _enable-pin.set enable-inverted-int
  
  set-min-pulsewidth minw/int:
    _min-pulse-width = minw

  set-enable-pin pin/int:
    _enable-pin = gpio.Pin pin --output
    if _enable-inverted:
      _enable-pin.set 0
    else:
      _enable-pin.set 1


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
