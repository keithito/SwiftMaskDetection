import argparse
import coremltools as ct
from coremltools.models import MLModel
import json
import numpy as np
from pathlib import Path
from PIL import Image, ImageDraw


# Copied from: https://github.com/AIZOOTech/FaceMaskDetection/blob/master/utils/anchor_generator.py
def generate_anchors(feature_map_sizes, anchor_sizes, anchor_ratios, offset=0.5):
  '''
  generate anchors.
  :param feature_map_sizes: list of list, for example: [[40,40], [20,20]]
  :param anchor_sizes: list of list, for example: [[0.05, 0.075], [0.1, 0.15]]
  :param anchor_ratios: list of list, for example: [[1, 0.5], [1, 0.5]]
  :param offset: default to 0.5
  '''
  anchor_bboxes = []
  for idx, feature_size in enumerate(feature_map_sizes):
    cx = (np.linspace(0, feature_size[0] - 1, feature_size[0]) + 0.5) / feature_size[0]
    cy = (np.linspace(0, feature_size[1] - 1, feature_size[1]) + 0.5) / feature_size[1]
    cx_grid, cy_grid = np.meshgrid(cx, cy)
    cx_grid_expend = np.expand_dims(cx_grid, axis=-1)
    cy_grid_expend = np.expand_dims(cy_grid, axis=-1)
    center = np.concatenate((cx_grid_expend, cy_grid_expend), axis=-1)

    num_anchors = len(anchor_sizes[idx]) +  len(anchor_ratios[idx]) - 1
    center_tiled = np.tile(center, (1, 1, 2* num_anchors))
    anchor_width_heights = []

    # different scales with the first aspect ratio
    for scale in anchor_sizes[idx]:
      ratio = anchor_ratios[idx][0] # select the first ratio
      width = scale * np.sqrt(ratio)
      height = scale / np.sqrt(ratio)
      anchor_width_heights.extend([-width / 2.0, -height / 2.0, width / 2.0, height / 2.0])

    # the first scale, with different aspect ratios (except the first one)
    for ratio in anchor_ratios[idx][1:]:
      s1 = anchor_sizes[idx][0] # select the first scale
      width = s1 * np.sqrt(ratio)
      height = s1 / np.sqrt(ratio)
      anchor_width_heights.extend([-width / 2.0, -height / 2.0, width / 2.0, height / 2.0])

    bbox_coords = center_tiled + np.array(anchor_width_heights)
    bbox_coords_reshape = bbox_coords.reshape((-1, 4))
    anchor_bboxes.append(bbox_coords_reshape)
  return np.concatenate(anchor_bboxes, axis=0)


# Copied from https://github.com/AIZOOTech/FaceMaskDetection/blob/master/utils/anchor_decode.py
def decode_bbox(anchors, raw_outputs, variances=[0.1, 0.1, 0.2, 0.2]):
  '''
  Decode the actual bbox according to the anchors.
  the anchor value order is:[xmin,ymin, xmax, ymax]
  :param anchors: numpy array with shape [batch, num_anchors, 4]
  :param raw_outputs: numpy array with the same shape with anchors
  :param variances: list of float, default=[0.1, 0.1, 0.2, 0.2]
  '''
  anchor_centers_x = (anchors[:,0:1] + anchors[:,2:3]) / 2
  anchor_centers_y = (anchors[:,1:2] + anchors[:,3:]) / 2
  anchors_w = anchors[:,2:3] - anchors[:,0:1]
  anchors_h = anchors[:,3:] - anchors[:,1:2]
  raw_outputs_rescale = raw_outputs * np.array(variances)
  predict_center_x = raw_outputs_rescale[:,0:1] * anchors_w + anchor_centers_x
  predict_center_y = raw_outputs_rescale[:,1:2] * anchors_h + anchor_centers_y
  predict_w = np.exp(raw_outputs_rescale[:,2:3]) * anchors_w
  predict_h = np.exp(raw_outputs_rescale[:,3:]) * anchors_h
  predict_xmin = predict_center_x - predict_w / 2
  predict_ymin = predict_center_y - predict_h / 2
  predict_xmax = predict_center_x + predict_w / 2
  predict_ymax = predict_center_y + predict_h / 2
  return np.concatenate([predict_xmin, predict_ymin, predict_xmax, predict_ymax], axis=-1)


# Copied from https://github.com/AIZOOTech/FaceMaskDetection/blob/master/utils/nms.py
def single_class_non_max_suppression(bboxes, confidences, conf_thresh=0.2, iou_thresh=0.5, keep_top_k=-1):
  '''
  do nms on single class.
  Hint: for the specific class, given the bbox and its confidence,
  1) sort the bbox according to the confidence from top to down, we call this a set
  2) select the bbox with the highest confidence, remove it from set, and do IOU calculate with the rest bbox
  3) remove the bbox whose IOU is higher than the iou_thresh from the set,
  4) loop step 2 and 3, util the set is empty.
  :param bboxes: numpy array of 2D, [num_bboxes, 4]
  :param confidences: numpy array of 1D. [num_bboxes]
  '''
  if len(bboxes) == 0: return []

  conf_keep_idx = np.where(confidences > conf_thresh)[0]

  bboxes = bboxes[conf_keep_idx]
  confidences = confidences[conf_keep_idx]

  pick = []
  xmin = bboxes[:, 0]
  ymin = bboxes[:, 1]
  xmax = bboxes[:, 2]
  ymax = bboxes[:, 3]

  area = (xmax - xmin + 1e-3) * (ymax - ymin + 1e-3)
  idxs = np.argsort(confidences)

  while len(idxs) > 0:
    last = len(idxs) - 1
    i = idxs[last]
    pick.append(i)

    # keep top k
    if keep_top_k != -1:
      if len(pick) >= keep_top_k:
        break

    overlap_xmin = np.maximum(xmin[i], xmin[idxs[:last]])
    overlap_ymin = np.maximum(ymin[i], ymin[idxs[:last]])
    overlap_xmax = np.minimum(xmax[i], xmax[idxs[:last]])
    overlap_ymax = np.minimum(ymax[i], ymax[idxs[:last]])
    overlap_w = np.maximum(0, overlap_xmax - overlap_xmin)
    overlap_h = np.maximum(0, overlap_ymax - overlap_ymin)
    overlap_area = overlap_w * overlap_h
    overlap_ratio = overlap_area / (area[idxs[:last]] + area[i] - overlap_area)

    need_to_be_deleted_idx = np.concatenate(([last], np.where(overlap_ratio > iou_thresh)[0]))
    idxs = np.delete(idxs, need_to_be_deleted_idx)
  return conf_keep_idx[pick]


# Dumps anchors to JSON, which can be
def dump_anchors(anchors, filename):
  array = []
  for anchor in anchors:
    array.append([round(x, 5) for x in anchor])
  s = json.dumps({'anchors': array}, separators=(',',':'))
  s = s.replace('[[', '[\n[').replace('],', '],\n')
  with open(filename, 'w') as out:
    out.write(s)
  print('Wrote %d anchors to: %s' % (len(array), filename))


# Anchor configuration.
# Copied from: https://github.com/AIZOOTech/FaceMaskDetection/blob/master/keras_infer.py
feature_map_sizes = [[33, 33], [17, 17], [9, 9], [5, 5], [3, 3]]
anchor_sizes = [[0.04, 0.056], [0.08, 0.11], [0.16, 0.22], [0.32, 0.45], [0.64, 0.72]]
anchor_ratios = [[1, 0.62, 0.42]] * 5
anchors = generate_anchors(feature_map_sizes, anchor_sizes, anchor_ratios)


def evaluate(args):
  print('Loading model: %s' % args.model)
  mlmodel = ct.models.MLModel(args.model)
  image = Image.open(args.image)
  result = mlmodel.predict({'data': image.resize((260, 260))})
  bboxes = decode_bbox(anchors, result['output_bounds'][0])
  max_labels = np.argmax(result['output_scores'][0], axis=1)
  max_scores = np.max(result['output_scores'][0], axis=1)
  keep_idxs = single_class_non_max_suppression(
    bboxes, max_scores, conf_thresh=args.conf_threshold, iou_thresh=args.iou_threshold)

  # Print the bounding boxes, labels, and scores
  label_names = {0: 'Mask', 1: 'No Mask'}
  colors = {0: 'green', 1: 'red'}
  for i in keep_idxs:
    print('%s %s %.3f' % (bboxes[i], label_names[max_labels[i]], max_scores[i]))

  # Draw predictions into the image
  draw = ImageDraw.Draw(image)
  for i in keep_idxs:
    x0, y0, x1, y1 = bboxes[i]
    x0 = max(0, x0 * image.width)
    y0 = max(0, y0 * image.height)
    x1 = min(image.width, x1 * image.width)
    y1 = min(image.height, y1 * image.height)
    color = 'gray'
    if max_scores[i] > 0.4:
      color = colors[max_labels[i]]
    draw.rectangle([x0, y0, x1, y1], outline=color, width=2)
  print('Writing to: /tmp/predictions.png')
  image.save('/tmp/predictions.png')

  if args.dump_anchors:
    dump_anchors(anchors, '/tmp/anchors.json')


if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('image', help='The image to evaluate')
  parser.add_argument('--model', required=True, help='Path to the mlmodel to evaluate')
  parser.add_argument('--conf_threshold', type=float, default=0.5)
  parser.add_argument('--iou_threshold', type=float, default=0.4)
  parser.add_argument('--dump_anchors', action='store_true', help='Write anchors to a JSON file')
  evaluate(parser.parse_args())
