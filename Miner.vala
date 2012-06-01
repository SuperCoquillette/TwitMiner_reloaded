using Gee;
using Json;
using Soup;

class Downloader {
  private TreeMap<string, string> _woeid;
  private string                  _filename;
  private File                    _file;
  private static string           TWITTER_REQUEST =
    "https://api.twitter.com/1/trends/%s.json";
  private bool                    _running = true;

  public Downloader(string filename = "test.csv"){
    _woeid = new TreeMap<string, string>();
    _woeid["World"          ] =  "1"       ;
    _woeid["Argentina"      ] =  "23424747";
    _woeid["Australia"      ] =  "23424748";
    _woeid["Brazil"         ] =  "23424768";
    _woeid["Canada"         ] =  "23424775";
    _woeid["Chile"          ] =  "23424782";
    _woeid["Colombia"       ] =  "23424787";
    _woeid["France"         ] =  "23424819";
    _woeid["Germany"        ] =  "23424829";
    _woeid["India"          ] =  "23424848";
    _woeid["Indonesia"      ] =  "23424846";
    _woeid["Ireland"        ] =  "23424803";
    _woeid["Italy"          ] =  "23424853";
    _woeid["Mexico"         ] =  "23424900";
    _woeid["Netherlands"    ] =  "23424909";
    _woeid["Singapore"      ] =  "23424948";
    _woeid["Spain"          ] =  "23424950";
    _woeid["Turkey"         ] =  "23424969";
    _woeid["United Kingdom" ] =  "23424975";
    _woeid["United States"  ] =  "23424977";
    _woeid["Venezuela"      ] =  "23424982";
    _filename                 =  filename;
    _file                     = File.new_for_path(_filename);
  }

  public void download(){
    Parser       parser  = new Json.Parser();
    SessionAsync session = new Soup.SessionAsync();
    Message      message = null;

    try{
      DataOutputStream os = new DataOutputStream(_file.query_exists() ?
          _file.append_to(FileCreateFlags.NONE) :
          _file.create(FileCreateFlags.REPLACE_DESTINATION));
      foreach(string key in _woeid.keys){
        if(!_running) break;
        stdout.printf("\r%-20s", key);
        stdout.flush();
        string url = TWITTER_REQUEST.printf(_woeid[key]);
        message = new Soup.Message("GET", url);
        session.send_message(message);

        string response = (string)message.response_body.data;
        parser.load_from_data(response, response.length);

        if(parser.get_root().get_array().get_object_element(0)
          .has_member("error")){

          stderr.printf("Limit reached\n");
        }else{
          os.put_string("%s; %s; ".printf(
            new DateTime.now_local().to_string(), key));

          foreach(var trends in parser.get_root().get_array()
            .get_object_element(0).get_array_member("trends").get_elements()){

            Json.Object trend = trends.get_object();
            os.put_string("%s; ".printf(trend.get_string_member("name")));
          }
          os.put_string("\n");

        }
        Thread.usleep(100 * 1000); /* 100ms */
      }
      os.close();
    }catch(Error e){
      stderr.printf("%s\n", e.message);
    }
  }

  public void stop(){
    _running = false;
  }
}

private Downloader d;

public void SignalHandler(int signum){
  if(d != null){
    d.stop();
  }
}

class CSV_to_Transaction {
  public static void translate(string input  = "test.csv",
                               string output = "test.trans",
                               string dico   = "test.dico"){

    File infile = File.new_for_path (input);
    File outfile = File.new_for_path(output);
    Builder jsonBuilder = new Builder();
    int i = 0;
    TreeMap<string, int> t = new TreeMap<string, int>();
    TreeMap<string, int> c = new TreeMap<string, int>();

    if(outfile.query_exists()){
      try{
        outfile.delete();
      }catch(Error e){
        stderr.printf("%s\n", e.message);
      }
    }

    try {
      DataInputStream  dis = new DataInputStream (infile.read ());
      string line;
      while ((line = dis.read_line (null)) != null) {
        string [] elements = line.split(";");
        foreach(string s in elements[1:elements.length-1]){
          s = s.strip();
          if(!t.has_key(s)){
            t[s] = i;
            c[s] = 0;
          }
          c[s] = c[s] + 1;
          ++i;
        }
      }
    } catch (Error e) {
      error ("%s", e.message);
    }

    /* Dumping dico */
    jsonBuilder.begin_array();
    foreach(string s in t.keys){
      jsonBuilder.begin_object();
        jsonBuilder.set_member_name("id");
        jsonBuilder.add_int_value(t[s]);

        jsonBuilder.set_member_name("tag");
        jsonBuilder.add_string_value(s);

        jsonBuilder.set_member_name("count");
        jsonBuilder.add_int_value(c[s]);
      jsonBuilder.end_object();
    }
    jsonBuilder.end_array();

    Generator g = new Generator();
    g.set_root(jsonBuilder.get_root());
    g.pretty = true;
    try{
      g.to_file(dico);
    }catch(Error e){
      stderr.printf("%s\n", e.message);
    }
    /* -- */

    try {
      DataInputStream  dis = new DataInputStream (infile.read ());
      DataOutputStream os = new DataOutputStream(
        outfile.create(FileCreateFlags.REPLACE_DESTINATION));
      string line;
      while ((line = dis.read_line (null)) != null) {
        string [] elements = line.split(";");
        foreach(string s in elements[1:elements.length-1]){
          s = s.strip();
          os.put_string("%d ".printf(t[s]));
        }
        os.put_string("\n");
      }
    } catch (Error e) {
      error ("%s", e.message);
    }

  }
}

class Transaction_to_CSV {
  public static void translate(string input  = "test.out",
                               string output = "test.out.csv",
                               string dico   = "test.dico"){
    Parser p = new Parser();
    try{
      if(!p.load_from_file(dico)){
        stderr.printf("Cannot open dico\n");
      }
    }catch(Error e){
      stderr.printf("%s\n", e.message);
    }

    Json.Node n = p.get_root();
    Json.Reader r = new Json.Reader(n.get_array().get_element(0));
    stdout.printf("%d :: ",(int)r.count_elements());
    r.read_element(0);
    stdout.printf("%d : ", (int)r.get_int_value());
    r.read_element(1);
    stdout.printf("%s\n", r.get_string_value());

  }
}

int main(){
  Posix.signal(Posix.SIGINT , SignalHandler);

  d = new Downloader("test.csv");
  d.download();

  CSV_to_Transaction.translate();
  //Transaction_to_CSV.translate();
  return 0;
}
