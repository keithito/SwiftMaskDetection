import argparse
import coremltools as ct
from coremltools.models import MLModel
import tensorflow as tf


# Converts the AIZOO face mask detector (https://github.com/AIZOOTech/FaceMaskDetection) to CoreML
def convert(args):
  print('Loading model: %s' % args.model)
  with open(args.model) as f:
    keras_model = tf.keras.models.model_from_json(f.read())

  print('Loading weights: %s' % args.weights)
  keras_model.load_weights(args.weights)

  print('Converting to coreml')
  mlmodel = ct.convert(keras_model,
                       inputs=[ct.ImageType(scale=1/255)],
                       minimum_deployment_target=ct.target.iOS13)

  print('Renaming outputs')
  spec = mlmodel.get_spec()
  ct.models.utils.rename_feature(spec, 'Identity', 'output_scores')
  ct.models.utils.rename_feature(spec, 'Identity_1', 'output_bounds')

  out_path = args.output if args.output else '/tmp/MaskModel.mlmodel'
  print('Saving to: %s' % out_path)
  ct.models.utils.save_spec(spec, out_path)


if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('--model', required=True,
    help='Path to the Keras model file, e.g. face_mask_detection.json')
  parser.add_argument('--weights', required=True,
    help='Path to the Keras weights file, e.g. face_mask_detection.hdf5')
  parser.add_argument('--output', help='Path to write the CoreML model to')
  convert(parser.parse_args())
