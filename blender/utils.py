import bpy
import json
import os
import glob
import lib.umsgpack
import platform

def write_arm(filepath, output):
    if bpy.data.worlds['Arm'].ArmMinimize:
        with open(filepath, 'wb') as f:
            f.write(lib.umsgpack.dumps(output))
    else:
        with open(filepath, 'w') as f:
            # f.write(json.dumps(output, separators=(',',':')))
            f.write(json.dumps(output, sort_keys=True, indent=4))

def get_fp():
    s = bpy.data.filepath.split(os.path.sep)
    s.pop()
    return os.path.sep.join(s)

def get_os():
    s = platform.system()
    if s == 'Windows':
        return 'win'
    elif s == 'Darwin':
        return 'mac'
    else:
        return 'linux'

def fetch_script_names():
    user_preferences = bpy.context.user_preferences
    addon_prefs = user_preferences.addons['armory'].preferences
    sdk_path = addon_prefs.sdk_path
    wrd = bpy.data.worlds['Arm']
    wrd.bundled_scripts_list.clear()
    os.chdir(sdk_path + '/armory/Sources/armory/trait')
    for file in glob.glob('*.hx'):
        wrd.bundled_scripts_list.add().name = file.rsplit('.')[0]
    wrd.scripts_list.clear()
    sources_path = get_fp() + '/Sources/' + wrd.ArmProjectPackage
    if os.path.isdir(sources_path):
        os.chdir(sources_path)
        for file in glob.glob('*.hx'):
            wrd.scripts_list.add().name = file.rsplit('.')[0]
    os.chdir(get_fp())

def to_hex(val):
    return '#%02x%02x%02x%02x' % (int(val[3] * 255), int(val[0] * 255), int(val[1] * 255), int(val[2] * 255))

def color_to_int(val):
    return (int(val[3] * 255) << 24) + (int(val[0] * 255) << 16) + (int(val[1] * 255) << 8) + int(val[2] * 255)

def safe_filename(s):
    s = s.replace('.', '_').replace('-', '_').replace(' ', '_')
    if s[0].isdigit(): # Prefix _ if first char is digit
        s = '_' + s
    return s

def safe_assetpath(s):
    return s[2:] # Remove leading '//'

def extract_filename_noext(s):
    return s.rsplit('/', 1)[1].rsplit('.', 1)[0] # Extract file name without extension

def get_render_resolution(scene_index=0):
    render = bpy.data.scenes[scene_index].render
    scale = render.resolution_percentage / 100
    return int(render.resolution_x * scale), int(render.resolution_y * scale)

def get_project_scene_name():
    wrd = bpy.data.worlds['Arm']
    if wrd.ArmPlayActiveScene:
        return safe_filename(bpy.context.screen.scene.name)
    else:
        return safe_filename(wrd.ArmProjectScene)
