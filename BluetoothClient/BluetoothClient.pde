PooBT_AC bt;

void setup()
{
  frameRate(1);
}

void onResume()
{
  super.onResume();
  bt = new PooBT_AC(this);  
  bt.init("KRAGAR");
}

void draw()
{
}

void onDestroy()
{
  bt.destroy();
}

void PooBT_ReceivedListener(byte[] bytes)
{
  println(new String(bytes));
}

void mousePressed() {
  bt.write(new String("Manna manna").getBytes());
}
