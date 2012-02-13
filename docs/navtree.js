var NAVTREE =
[
  [ "CouchCocoa", "index.html", [
    [ "About CouchCocoa", "index.html", null ],
    [ "Class List", "annotated.html", [
      [ "CouchAttachment", "interfaceCouchAttachment.html", null ],
      [ "CouchbaseCallbacks", "interfaceCouchbaseCallbacks.html", null ],
      [ "<CouchbaseDelegate>", "protocolCouchbaseDelegate-p.html", null ],
      [ "CouchbaseMobile", "interfaceCouchbaseMobile.html", null ],
      [ "<CouchbaseValidationContext>", "protocolCouchbaseValidationContext-p.html", null ],
      [ "CouchChangeTracker", "interfaceCouchChangeTracker.html", null ],
      [ "CouchDatabase", "interfaceCouchDatabase.html", null ],
      [ "CouchDesignDocument", "interfaceCouchDesignDocument.html", null ],
      [ "CouchDocument", "interfaceCouchDocument.html", null ],
      [ "<CouchDocumentModel>", "protocolCouchDocumentModel-p.html", null ],
      [ "CouchDynamicObject", "interfaceCouchDynamicObject.html", null ],
      [ "CouchEmbeddedServer", "interfaceCouchEmbeddedServer.html", null ],
      [ "CouchLiveQuery", "interfaceCouchLiveQuery.html", null ],
      [ "CouchModel", "interfaceCouchModel.html", null ],
      [ "CouchModelFactory", "interfaceCouchModelFactory.html", null ],
      [ "CouchPersistentReplication", "interfaceCouchPersistentReplication.html", null ],
      [ "CouchQuery", "interfaceCouchQuery.html", null ],
      [ "CouchQueryEnumerator", "interfaceCouchQueryEnumerator.html", null ],
      [ "CouchQueryRow", "interfaceCouchQueryRow.html", null ],
      [ "CouchReplication", "interfaceCouchReplication.html", null ],
      [ "CouchResource", "interfaceCouchResource.html", null ],
      [ "CouchRevision", "interfaceCouchRevision.html", null ],
      [ "CouchServer", "interfaceCouchServer.html", null ],
      [ "RESTBase64", "interfaceRESTBase64.html", null ],
      [ "RESTBody", "interfaceRESTBody.html", null ],
      [ "RESTCache", "interfaceRESTCache.html", null ],
      [ "RESTMutableBody", "interfaceRESTMutableBody.html", null ],
      [ "RESTOperation", "interfaceRESTOperation.html", null ],
      [ "RESTResource", "interfaceRESTResource.html", null ],
      [ "<RESTResourceDelegate>", "protocolRESTResourceDelegate-p.html", null ]
    ] ],
    [ "Class Index", "classes.html", null ],
    [ "Class Hierarchy", "hierarchy.html", [
      [ "CouchbaseCallbacks", "interfaceCouchbaseCallbacks.html", null ],
      [ "<CouchbaseDelegate>", "protocolCouchbaseDelegate-p.html", null ],
      [ "CouchbaseMobile", "interfaceCouchbaseMobile.html", null ],
      [ "<CouchbaseValidationContext>", "protocolCouchbaseValidationContext-p.html", null ],
      [ "CouchChangeTracker", "interfaceCouchChangeTracker.html", null ],
      [ "<CouchDocumentModel>", "protocolCouchDocumentModel-p.html", null ],
      [ "CouchDynamicObject", "interfaceCouchDynamicObject.html", [
        [ "CouchModel", "interfaceCouchModel.html", [
          [ "CouchPersistentReplication", "interfaceCouchPersistentReplication.html", null ]
        ] ]
      ] ],
      [ "CouchModelFactory", "interfaceCouchModelFactory.html", null ],
      [ "CouchQueryEnumerator", "interfaceCouchQueryEnumerator.html", null ],
      [ "CouchQueryRow", "interfaceCouchQueryRow.html", null ],
      [ "CouchReplication", "interfaceCouchReplication.html", null ],
      [ "RESTBase64", "interfaceRESTBase64.html", null ],
      [ "RESTBody", "interfaceRESTBody.html", [
        [ "RESTMutableBody", "interfaceRESTMutableBody.html", null ]
      ] ],
      [ "RESTCache", "interfaceRESTCache.html", null ],
      [ "RESTOperation", "interfaceRESTOperation.html", null ],
      [ "RESTResource", "interfaceRESTResource.html", [
        [ "CouchResource", "interfaceCouchResource.html", [
          [ "CouchAttachment", "interfaceCouchAttachment.html", null ],
          [ "CouchDatabase", "interfaceCouchDatabase.html", null ],
          [ "CouchDocument", "interfaceCouchDocument.html", [
            [ "CouchDesignDocument", "interfaceCouchDesignDocument.html", null ]
          ] ],
          [ "CouchQuery", "interfaceCouchQuery.html", [
            [ "CouchLiveQuery", "interfaceCouchLiveQuery.html", null ]
          ] ],
          [ "CouchRevision", "interfaceCouchRevision.html", null ],
          [ "CouchServer", "interfaceCouchServer.html", [
            [ "CouchEmbeddedServer", "interfaceCouchEmbeddedServer.html", null ]
          ] ]
        ] ]
      ] ],
      [ "<RESTResourceDelegate>", "protocolRESTResourceDelegate-p.html", null ]
    ] ],
    [ "Class Members", "functions.html", null ],
    [ "File List", "files.html", [
      [ "Couch/CouchAttachment.h", null, null ],
      [ "Couch/CouchbaseCallbacks.h", null, null ],
      [ "Couch/CouchbaseMobile.h", null, null ],
      [ "Couch/CouchChangeTracker.h", null, null ],
      [ "Couch/CouchCocoa.h", null, null ],
      [ "Couch/CouchDatabase.h", null, null ],
      [ "Couch/CouchDesignDocument.h", null, null ],
      [ "Couch/CouchDesignDocument_Embedded.h", null, null ],
      [ "Couch/CouchDocument.h", null, null ],
      [ "Couch/CouchEmbeddedServer.h", null, null ],
      [ "Couch/CouchPersistentReplication.h", null, null ],
      [ "Couch/CouchQuery.h", null, null ],
      [ "Couch/CouchReplication.h", null, null ],
      [ "Couch/CouchResource.h", null, null ],
      [ "Couch/CouchRevision.h", null, null ],
      [ "Couch/CouchServer.h", null, null ],
      [ "Model/CouchDynamicObject.h", null, null ],
      [ "Model/CouchModel.h", null, null ],
      [ "Model/CouchModelFactory.h", null, null ],
      [ "REST/REST.h", null, null ],
      [ "REST/RESTBase64.h", null, null ],
      [ "REST/RESTBody.h", null, null ],
      [ "REST/RESTCache.h", null, null ],
      [ "REST/RESTOperation.h", null, null ],
      [ "REST/RESTResource.h", null, null ]
    ] ]
  ] ]
];

function createIndent(o,domNode,node,level)
{
  if (node.parentNode && node.parentNode.parentNode)
  {
    createIndent(o,domNode,node.parentNode,level+1);
  }
  var imgNode = document.createElement("img");
  if (level==0 && node.childrenData)
  {
    node.plus_img = imgNode;
    node.expandToggle = document.createElement("a");
    node.expandToggle.href = "javascript:void(0)";
    node.expandToggle.onclick = function() 
    {
      if (node.expanded) 
      {
        $(node.getChildrenUL()).slideUp("fast");
        if (node.isLast)
        {
          node.plus_img.src = node.relpath+"ftv2plastnode.png";
        }
        else
        {
          node.plus_img.src = node.relpath+"ftv2pnode.png";
        }
        node.expanded = false;
      } 
      else 
      {
        expandNode(o, node, false);
      }
    }
    node.expandToggle.appendChild(imgNode);
    domNode.appendChild(node.expandToggle);
  }
  else
  {
    domNode.appendChild(imgNode);
  }
  if (level==0)
  {
    if (node.isLast)
    {
      if (node.childrenData)
      {
        imgNode.src = node.relpath+"ftv2plastnode.png";
      }
      else
      {
        imgNode.src = node.relpath+"ftv2lastnode.png";
        domNode.appendChild(imgNode);
      }
    }
    else
    {
      if (node.childrenData)
      {
        imgNode.src = node.relpath+"ftv2pnode.png";
      }
      else
      {
        imgNode.src = node.relpath+"ftv2node.png";
        domNode.appendChild(imgNode);
      }
    }
  }
  else
  {
    if (node.isLast)
    {
      imgNode.src = node.relpath+"ftv2blank.png";
    }
    else
    {
      imgNode.src = node.relpath+"ftv2vertline.png";
    }
  }
  imgNode.border = "0";
}

function newNode(o, po, text, link, childrenData, lastNode)
{
  var node = new Object();
  node.children = Array();
  node.childrenData = childrenData;
  node.depth = po.depth + 1;
  node.relpath = po.relpath;
  node.isLast = lastNode;

  node.li = document.createElement("li");
  po.getChildrenUL().appendChild(node.li);
  node.parentNode = po;

  node.itemDiv = document.createElement("div");
  node.itemDiv.className = "item";

  node.labelSpan = document.createElement("span");
  node.labelSpan.className = "label";

  createIndent(o,node.itemDiv,node,0);
  node.itemDiv.appendChild(node.labelSpan);
  node.li.appendChild(node.itemDiv);

  var a = document.createElement("a");
  node.labelSpan.appendChild(a);
  node.label = document.createTextNode(text);
  a.appendChild(node.label);
  if (link) 
  {
    a.href = node.relpath+link;
  } 
  else 
  {
    if (childrenData != null) 
    {
      a.className = "nolink";
      a.href = "javascript:void(0)";
      a.onclick = node.expandToggle.onclick;
      node.expanded = false;
    }
  }

  node.childrenUL = null;
  node.getChildrenUL = function() 
  {
    if (!node.childrenUL) 
    {
      node.childrenUL = document.createElement("ul");
      node.childrenUL.className = "children_ul";
      node.childrenUL.style.display = "none";
      node.li.appendChild(node.childrenUL);
    }
    return node.childrenUL;
  };

  return node;
}

function showRoot()
{
  var headerHeight = $("#top").height();
  var footerHeight = $("#nav-path").height();
  var windowHeight = $(window).height() - headerHeight - footerHeight;
  navtree.scrollTo('#selected',0,{offset:-windowHeight/2});
}

function expandNode(o, node, imm)
{
  if (node.childrenData && !node.expanded) 
  {
    if (!node.childrenVisited) 
    {
      getNode(o, node);
    }
    if (imm)
    {
      $(node.getChildrenUL()).show();
    } 
    else 
    {
      $(node.getChildrenUL()).slideDown("fast",showRoot);
    }
    if (node.isLast)
    {
      node.plus_img.src = node.relpath+"ftv2mlastnode.png";
    }
    else
    {
      node.plus_img.src = node.relpath+"ftv2mnode.png";
    }
    node.expanded = true;
  }
}

function getNode(o, po)
{
  po.childrenVisited = true;
  var l = po.childrenData.length-1;
  for (var i in po.childrenData) 
  {
    var nodeData = po.childrenData[i];
    po.children[i] = newNode(o, po, nodeData[0], nodeData[1], nodeData[2],
        i==l);
  }
}

function findNavTreePage(url, data)
{
  var nodes = data;
  var result = null;
  for (var i in nodes) 
  {
    var d = nodes[i];
    if (d[1] == url) 
    {
      return new Array(i);
    }
    else if (d[2] != null) // array of children
    {
      result = findNavTreePage(url, d[2]);
      if (result != null) 
      {
        return (new Array(i).concat(result));
      }
    }
  }
  return null;
}

function initNavTree(toroot,relpath)
{
  var o = new Object();
  o.toroot = toroot;
  o.node = new Object();
  o.node.li = document.getElementById("nav-tree-contents");
  o.node.childrenData = NAVTREE;
  o.node.children = new Array();
  o.node.childrenUL = document.createElement("ul");
  o.node.getChildrenUL = function() { return o.node.childrenUL; };
  o.node.li.appendChild(o.node.childrenUL);
  o.node.depth = 0;
  o.node.relpath = relpath;

  getNode(o, o.node);

  o.breadcrumbs = findNavTreePage(toroot, NAVTREE);
  if (o.breadcrumbs == null)
  {
    o.breadcrumbs = findNavTreePage("index.html",NAVTREE);
  }
  if (o.breadcrumbs != null && o.breadcrumbs.length>0)
  {
    var p = o.node;
    for (var i in o.breadcrumbs) 
    {
      var j = o.breadcrumbs[i];
      p = p.children[j];
      expandNode(o,p,true);
    }
    p.itemDiv.className = p.itemDiv.className + " selected";
    p.itemDiv.id = "selected";
    $(window).load(showRoot);
  }
}

