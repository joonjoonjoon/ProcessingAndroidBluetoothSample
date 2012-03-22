PooBT_PCS bt;

void setup ()
{
  bt = new PooBT_PCS(this);
  bt.init();
}

void draw()
{
  
}

void PooBT_ReceivedListener(byte[] bytes)
{
  println(new String(bytes));
}

void mousePressed() {
  bt.write(new String("Tu-tuu tidudu").getBytes());
}
