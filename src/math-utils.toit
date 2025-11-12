max_val val_1/num val_2/num -> num:
  if val_1 > val_2:
    return val_1
  return val_2

min_val val_1/num val_2/num -> num:
  if val_1 < val_2:
    return val_1
  return val_2

constrain val/float min-val/float max-val/float -> float:
  return min (max val min-val) max-val

fabs val/float:
  if val > 0:
    return val

  return -val