from PIL import Image, ImageChops
import json
paths={"speaker_on":"C:\\Users\\geniu\\.codex\\generated_images\\01a1295b-f305-7352-aa06-e6cf330f3987\\exec-7eabc933-f702-4844-8920-8b3a99b569d1.png","speaker_off":"C:\\Users\\geniu\\.codex\\generated_images\\01a1295b-f305-7352-aa06-e6cf330f3987\\exec-b5a19c7b-4d8f-4e4a-82a3-e0f83e85c7a3.png","corner":"C:\\Users\\geniu\\.codex\\generated_images\\01a1295b-f305-7352-aa06-e6cf330f3987\\exec-7b1ff499-b5cc-4326-bb2b-9c9f20efb4b9.png","warning":"C:\\Users\\geniu\\.codex\\generated_images\\01a1295b-f305-7352-aa06-e6cf330f3987\\exec-07c3d271-ae05-4847-bb82-fdd2658d3b47.png","streak":"C:\\Users\\geniu\\.codex\\generated_images\\01a1295b-f305-7352-aa06-e6cf330f3987\\exec-7331f580-1377-47ff-9692-98dd32dc4255.png"}
for k,p in paths.items():
 im=Image.open(p).convert('RGBA')
 for t in [8,32,64,128,200]:
  a=im.getchannel('A').point(lambda x:255 if x>t else 0)
  print(k,t,a.getbbox())
a=Image.open(paths['speaker_on']).convert('RGBA').resize((512,512),Image.Resampling.LANCZOS).getchannel('A').point(lambda x:255 if x>128 else 0)
b=Image.open(paths['speaker_off']).convert('RGBA').resize((512,512),Image.Resampling.LANCZOS).getchannel('A').point(lambda x:255 if x>128 else 0)
diff=ImageChops.difference(a,b)
print('512 speaker threshold alpha mismatch pixels',sum(1 for v in diff.getdata() if v>0),'ratio',sum(1 for v in diff.getdata() if v>0)/(512*512))

