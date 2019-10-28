using System.Collections.Generic;

namespace OneBill
{
    public class Provider
    {
        public string ProviderCode { get; set; }
        public string Name { get; set; }
        public bool Payable { get; set; }
        public bool Form { get; set; }
        public List<string> Parents { get; set; }
        public List<Provider> Children { get; set; }
        public string Status { get; set; }

        public List<Provider> ToList()
        {
            List<Provider> providerList = new List<Provider>();
            int count = this.Children.Count;

            if (count > 0)
            {
                foreach (var p in this.Children)
                {
                    if (p.Form ^ p.Payable)
                    {
                        p.Status = "Incorrect";              
                    }else if(!p.Form && !p.Payable){
						p.Status = "Folder";
					}else
					{
						p.Status = "Provider";
					}
                    providerList.Add(p);
                    providerList.AddRange(p.ToList());
                }
            }

            return providerList;
        }
    }
}
