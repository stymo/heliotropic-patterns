"""
Process to move a file from one location to another. 
"""
import glob
import os
import shutil
import time
import typing as t

import paramiko
from PIL import Image
from PIL.ImageOps import exif_transpose


 
 # remove dirs
SRC_DIR = os.environ['IMG_DOWNLOADER_SRC_DIR']
ARCHIVE_DIR = os.environ['IMG_DOWNLOADER_ARCHIVE_DIR']
# local dirs
TMP_DIR = 'tmp'
DST_DIR = os.environ['IMG_DOWNLOADER_DST_DIR']
ALLOWED_EXTS = ['jpeg','jpg','JPEG','JPG']
GLOBS = ['/*.jpeg','/*.jpg','/*.JPEG','/*.JPG']

HOSTNAME = os.environ['SSH_HOSTNAME']
PORT = os.environ['SSH_PORT']
USERNAME = os.environ['SSH_USERNAME']
PASSWORD = os.environ['SSH_PASSWORD']

# globals - suss? at least wrap in a try/except
ssh_client = paramiko.SSHClient()
ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh_client.connect(HOSTNAME, port=PORT, username=USERNAME, password=PASSWORD)


def get_src_contents() -> set:
    uploaded_files = set([])
    # try:
    stdin, stdout, stderr = ssh_client.exec_command(f'ls -l {SRC_DIR}')
    output = stdout.read().decode("utf-8")
    print(output)
    uploaded_files = output.split('\n')
    print(uploaded_files)
    uploaded_files = [output_line.split(' ')[-1] for output_line in uploaded_files if output_line.split('.')[-1] in ALLOWED_EXTS]
    print(uploaded_files)
        
    return set(uploaded_files)


def get_dst_contents() -> set:
    filenames = []
    for g in GLOBS:
        matches = glob.glob(DST_DIR + g)
        for m in matches:
            filenames.append(os.path.basename(m))
    return set(filenames)


def get_new_filenames() -> t.Set[str]:
    src_contents = get_src_contents()
    dst_contents = get_dst_contents()
    new_files = src_contents - dst_contents
    return new_files


def download_new_files(filenames: t.Set[str]):
    new_filenames = get_new_filenames()
    for f in new_filenames:
        remote_path = SRC_DIR + f'/{f}'
        local_path = TMP_DIR + f'/{f}'
        sftp = paramiko.SFTPClient.from_transport(ssh_client.get_transport())
        sftp.get(remote_path, local_path)
        print(f"File downloaded successfully from {remote_path} to {local_path}")
        # process file
        im = Image.open(local_path)
        exif_transpose(im, in_place=True)
        print(f'curr image size: {im.width}, {im.height}')
        if im.width > 1000 or im.height > 1000:
            print('resizing...')
            im.thumbnail((1000, 1000))
        # first save to tmp dir, then move so Processing doesn't pick up partial file    
        im.save(local_path)
        final_path = DST_DIR + f'/{f}'            
        print(f'writing processed file to {final_path}') 
        shutil.copy2(local_path, final_path)
        arch_path = ARCHIVE_DIR + f'/{f}'
        print(f'archiving file on server as {arch_path}')
        sftp.rename(remote_path, arch_path)


def main():
    while 1:
        print('checking for new files')
        new_filenames = get_new_filenames()
        if new_filenames:
            print('found new files')
            download_new_files(new_filenames)
        time.sleep(10)            

   
if __name__ == '__main__':
    main()

