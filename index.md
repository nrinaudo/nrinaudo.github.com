---
---
<ul class="archive">
  {% for post in site.posts %}
  <li>
  <div>
   <div class="meta">
   <time pubdate datetime="{{post.date | date: "%Y-%m-%d"}}">{{ post.date | date: "%B  %-d, %Y" }}</time>
   </div>
   <div class="title"><a href="{{ post.url }}">{{ post.title }}</a></div>
   </div>
   {{ post.excerpt }}
  </li>
  {% endfor %}
</ul>
