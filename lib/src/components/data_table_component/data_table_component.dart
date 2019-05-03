import 'dart:async';
import 'dart:html';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:angular/angular.dart';
import 'package:angular_forms/angular_forms.dart';
import 'package:angular_router/angular_router.dart';

import 'serialization_interface.dart';
import 'response_list.dart';
import 'data_table_filter.dart';

//utils
import 'utils.dart';

@Component(
  selector: 'data-table',
  templateUrl: 'data_table_component.html',
  styleUrls: [
    'data_table_component.css',
  ],
  directives: [
    formDirectives,
    coreDirectives,
    routerDirectives,
  ],
)
//A Material Design Data table component for AngularDart
class DataTableComponent implements OnInit, AfterChanges, AfterViewInit {
  @ViewChild("tableElement") //HtmlElement
  TableElement tableElement;

  DataTableFilter dataTableFilter = new DataTableFilter();

  @ViewChild("inputSearchElement")
  InputElement inputSearchElement;

  @ViewChild("itemsPerPageElement")
  SelectElement itemsPerPageElement;

  @ViewChild("paginateContainer")
  HtmlElement paginateContainer;

  @ViewChild("paginateDiv")
  HtmlElement paginateDiv;

  @ViewChild("paginatePrevBtn")
  HtmlElement paginatePrevBtn;

  @ViewChild("paginateNextBtn")
  HtmlElement paginateNextBtn;

  @Input()
  bool showFilter = true;

  @Input()
  bool showItemsLimit = true;

  bool _showCheckBoxToSelectRow = true;

  RList<ISerialization> _data;
  RList<ISerialization> selectedItems = new RList<ISerialization>();

  @Input()
  set data(RList<ISerialization> data) {
    _data = data;
  }

  RList<ISerialization> get data {
    return _data;
  }

  int get totalRecords {
    if (_data != null) {
      return _data.totalRecords;
    }
    return 0;
  }

  int _currentPage = 1;
  int _btnQuantity = 5;
  PaginationType paginationType = PaginationType.carousel;
  StreamSubscription _prevBtnStreamSub;
  StreamSubscription _nextBtnStreamSub;

  final NodeValidatorBuilder _htmlValidator = new NodeValidatorBuilder.common()
    ..allowHtml5()
    ..allowImages()
    ..allowInlineStyles()
    ..allowTextElements()
    ..allowSvg()
    ..allowElement('a', attributes: ['href'])
    ..allowElement('img', attributes: ['src']);

  @override
  void ngOnInit() {}

  /*@override
  void ngOnChanges(Map<String, SimpleChange> changes) {
    draw();
  }*/

  ngAfterViewInit() {
    inputSearchElement.onKeyPress.listen((KeyboardEvent e) {
      if (e.keyCode == KeyCode.ENTER) {
        onSearch();
      }
    });
    _prevBtnStreamSub = paginatePrevBtn.onClick.listen(prevPage);
    _nextBtnStreamSub = paginateNextBtn.onClick.listen(nextPage);
  }

  @override
  void ngAfterChanges() {
    draw();
    drawPagination();
  }

  void draw() {
    try {
      //clear tbody if not get data
      if (_data == null || _data.isEmpty) {
        var tbody = tableElement.querySelector('tbody');
        if (tbody != null) {
          tbody.innerHtml = "<tr><td>Dados indisponiveis</td></tr>";
        } else {
          TableSectionElement tBody = tableElement.createTBody();
          tBody.innerHtml = "<tr><td>Dados indisponiveis</td></tr>";
        }
      }
      if (_data != null) {
        if (_data.isNotEmpty) {
          tableElement.innerHtml = "";

          List<Map<String, dynamic>> columns = _data[0].toDisplayNames();

          Element tableHead = tableElement.createTHead();
          TableRowElement tableHeaderRow = tableElement.tHead.insertRow(-1);
          //show checkbox on tableHead to select all rows
          if (_showCheckBoxToSelectRow) {
            var th = new Element.tag('th');
            var label = new Element.tag('label');
            label.classes.add("pure-material-checkbox");
            var input = new CheckboxInputElement();
            //input.type = "checkbox";
            input.onClick.listen(onSelectAll);
            var span = new Element.tag('span');
            label.append(input);
            label.append(span);
            th.append(label);
            tableHeaderRow.insertAdjacentElement('beforeend', th);
          }
          //render colunas de titulo
          for (final col in columns) {
            var key = col.containsKey('key') ? col['key'] : null;
            var title = col.containsKey('title') ? col['title'] : null;
            var type = col.containsKey('type') ? col['type'] : null;
            var limit = col.containsKey('limit') ? col['limit'] : null;

            var th = new Element.tag('th');
            th.text = title;
            tableHeaderRow.insertAdjacentElement('beforeend', th);
          }
          //render linhas
          TableSectionElement tBody = tableElement.createTBody();
          for (final item in _data) {
            var row = item.toJson();

            TableRowElement tableRow = tBody.insertRow(-1);
            //show checkbox to select single row
            if (_showCheckBoxToSelectRow) {
              var tdcb = new Element.tag('td');
              var label = new Element.tag('label');
              label.onClick.listen((e) {
                e.stopPropagation();
              });
              label.classes.add("pure-material-checkbox");
              var input = new CheckboxInputElement();
              //input.type = "checkbox";
              input.attributes['cbSelect'] = "true";
              input.onClick.listen((MouseEvent event) {
                onSelect(event, item);
              });
              var span = new Element.tag('span');
              span.onClick.listen((e) {
                e.stopPropagation();
              });
              label.append(input);
              label.append(span);
              tdcb.append(label);
              tableRow.insertAdjacentElement('beforeend', tdcb);
            }

            tableRow.onClick.listen((event) {
              /*if (_showCheckBoxToSelectRow) {
              HtmlElement el = event.target;
              TableCellElement tc = el.closest("td");
              if (tc != null && tc.cellIndex > 0) {
                onRowClick(item);
              }
            } else {
              onRowClick(item);
            }*/
              onRowClick(item);
            });

            //draw columns
            for (final col in columns) {
              var key = col.containsKey('key') ? col['key'] : null;
              var title = col.containsKey('title') ? col['title'] : null;
              var type = col.containsKey('type') ? col['type'] : null;
              var limit = col.containsKey('limit') ? col['limit'] : null;
              var format = col.containsKey('format') ? col['format'] : null;
              var tdContent = "";

              switch (type.toString()) {
                case 'date':
                  if (row[key.toString()] != null) {
                    var fmt = format == null ? 'dd/MM/yyyy' : format;
                    var formatter = new DateFormat(fmt);
                    var date = DateTime.tryParse(row[key].toString());
                    if (date != null) {
                      tdContent = formatter.format(date);
                    }
                  }
                  break;
                case 'string':
                  var str = row[key.toString()].toString();
                  if (limit != null) {
                    str = Utils.truncate(str, limit);
                  }
                  tdContent = str;
                  break;
                case 'img':
                  var src = row[key.toString()].toString();
                  if (src != "null") {
                    var img = ImageElement();
                    img.src = src;
                    img.height = 40;
                    tdContent = img.outerHtml;
                  } else {
                    tdContent = "-";
                  }
                  break;
                default:
                  tdContent = row[key.toString()].toString();
              }

              tdContent = tdContent == "null" ? "-" : tdContent;

              var td = new Element.tag('td');
              td.setInnerHtml(tdContent,
                  treeSanitizer: NodeTreeSanitizer.trusted);

              tableRow.insertAdjacentElement('beforeend', td);
            }
          }
        }
      }
    } catch (exception, stackTrace) {
      print("draw() exception: " + exception.toString());
      print(stackTrace.toString());
    }
  }

  int numPages() {
    var totalPages = (this.totalRecords / this.dataTableFilter.limit).ceil();
    return totalPages;
  }

  void drawPagination() {
    var self = this;
    //quantidade total de paginas
    var totalPages = numPages();

    //quantidade de botões de paginação exibidos
    var btnQuantity =
        self._btnQuantity > totalPages ? totalPages : self._btnQuantity;
    var currentPage = self._currentPage; //pagina atual
    //clear paginateContainer for new draws
    self.paginateContainer.innerHtml = "";
    if (self.totalRecords < self.dataTableFilter.limit) {
      return;
    }

    if (btnQuantity == 1) {
      return;
    }

    if (currentPage == 1) {
      paginatePrevBtn.classes.remove('disabled');
      paginatePrevBtn.classes.add('disabled');
    }

    if (currentPage == totalPages) {
      paginateNextBtn.classes.remove('disabled');
      paginateNextBtn.classes.add('disabled');
    }

    var idx = 0;
    var loopEnd = 0;
    switch (paginationType) {
      case PaginationType.carousel:
        idx = currentPage - (btnQuantity / 2).toInt();
        if (idx <= 0) {
          idx = 1;
        }
        loopEnd = idx + btnQuantity;
        if (loopEnd > totalPages) {
          loopEnd = totalPages + 1;
          idx = loopEnd - btnQuantity;
        }
        while (idx < loopEnd) {
          var link = new Element.tag('a');
          link.classes.add("paginate_button");
          if (idx == currentPage) {
            link.classes.add("current");
          }
          link.text = idx.toString();
          var liten = (event) {
            var pageBtnValue = int.tryParse(link.text);
            if (self._currentPage != pageBtnValue) {
              self._currentPage = pageBtnValue;
              self.changePage(self._currentPage);
            }
          };
          link.onClick.listen(liten);
          self.paginateContainer.append(link);
          idx++;
        }
        break;
      case PaginationType.cube:
        var facePosition = (currentPage % btnQuantity) == 0
            ? btnQuantity
            : currentPage % btnQuantity;
        loopEnd = btnQuantity - facePosition + currentPage;
        idx = currentPage - facePosition;
        while (idx < loopEnd) {
          idx++;
          if (idx <= totalPages) {
            var link = new Element.tag('a');
            link.classes.add("paginate_button");
            if (idx == currentPage) {
              link.classes.add("current");
            }
            link.text = idx.toString();
            var liten = (event) {
              var pageBtnValue = int.tryParse(link.text);
              if (self._currentPage != pageBtnValue) {
                self._currentPage = pageBtnValue;
                self.changePage(self._currentPage);
              }
            };
            link.onClick.listen(liten);
            self.paginateContainer.append(link);
          }
        }
        break;
    }
  }

  prevPage(Event event) {
    if (this._currentPage == 0) {
      return;
    }
    if (this._currentPage > 1) {
      this._currentPage--;
      changePage(this._currentPage);
    }
  }

  nextPage(Event event) {
    if (this._currentPage == numPages()) {
      return;
    }
    if (this._currentPage < this.numPages()) {
      this._currentPage++;
      changePage(this._currentPage);
    }
  }

  changePage(page) {
    onRequestData();
    if (page != this._currentPage) {
      this._currentPage = page;
    }
    selectedItems.clear();
  }

  final _rowClickRequest = StreamController<ISerialization>();

  @Output()
  Stream<ISerialization> get rowClick => _rowClickRequest.stream;

  onRowClick(ISerialization item) {
    _rowClickRequest.add(item);
  }

  final _searchRequest = StreamController<DataTableFilter>();

  @Output()
  Stream<DataTableFilter> get searchRequest => _searchRequest.stream;

  onSearch() {
    dataTableFilter.searchString = inputSearchElement.value;
    _searchRequest.add(dataTableFilter);
    onRequestData();
  }

  final _limitChangeRequest = StreamController<DataTableFilter>();

  @Output()
  Stream<DataTableFilter> get limitChange => _limitChangeRequest.stream;

  onLimitChange() {
    this._currentPage = 1;
    dataTableFilter.limit = int.tryParse(itemsPerPageElement.value);
    _limitChangeRequest.add(dataTableFilter);
    onRequestData();
  }

  final _dataRequest = StreamController<DataTableFilter>();

  @Output()
  Stream<DataTableFilter> get dataRequest => _dataRequest.stream;

  onRequestData() {
    var currentPage = this._currentPage == 1 ? 0 : this._currentPage - 1;
    dataTableFilter.offset = currentPage * dataTableFilter.limit;
    _dataRequest.add(dataTableFilter);
  }

  onSelectAll(event) {
    var cbs = tableElement.querySelectorAll('input[cbselect=true]');
    if (event.target.checked) {
      for (CheckboxInputElement item in cbs) {
        item.checked = true;
      }
      selectedItems.clear();
      selectedItems.addAll(_data);
    } else {
      selectedItems.clear();
      for (CheckboxInputElement item in cbs) {
        item.checked = false;
      }
    }
  }

  onSelect(MouseEvent event, ISerialization item) {
    event.stopPropagation();
    CheckboxInputElement cb = event.target;
    if (cb.checked) {
      if (selectedItems.contains(item) == false) {
        selectedItems.add(item);
      }
    } else {
      if (selectedItems.contains(item)) {
        selectedItems.remove(item);
      }
    }
  }
}

enum PaginationType { carousel, cube }
