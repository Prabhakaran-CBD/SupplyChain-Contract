//"SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

/*Creating a new contract 'item' for the payment process
so this item contract should receive the item no(index of the item) from the item manager contract to do the payment for
that particular item, then this item contract should send the payment details to item manager contract.
so item manger contract should manage to receive the payment information for the particular item
*/
//create the contract to make sure the ownership control
//create an abstract contract when that contract is non-deployable
abstract contract Ownable{
    address  Owner;
    
    constructor () {
        Owner = msg.sender;
        
    }
    
    modifier OnlyOwner{
        require(isOwner(),'You are not the owner');
        _;
    }
    
    function isOwner() internal view returns(bool){
        return (Owner == msg.sender);
    }
}

//Bascially commnuication between two contracts,so both contract should called in and another 
//Note - contract level communication to share or to pass the value should be done thru
//the constructor
contract Item {
    
    uint index;
    uint public priceInWei;
    uint PaymentDone;
    ItemManager prarentContract; //type of ItemManager contract to receive the address of the contract
    
    //need item no (item index), price of the item and manager details from the Item Manager contract
    //note cconstructor visibility can be public or internal or plain(empty) but it can not be external
    constructor(ItemManager _parentContract,uint _itemIndex, uint _priceInWei) {
        prarentContract = _parentContract;
        index = _itemIndex;
        priceInWei = _priceInWei;
        
    }
    
    //need to receive plain ether to run this contract
    receive() external payable{
        /*
        //this will cost more gas..so  to avaoid this we are using low level call() function
        payable(address(prarentContract)).transfer(msg.value);
        prarentContract.triggerPayment(index);
        */
        
        require(PaymentDone == 0, "Payment is already received");
        require(priceInWei == msg.value, "Only full payment is accepted");
        
        PaymentDone += msg.value;
       
        
        //address(prarentContract).call.value(msg.value);
         (bool success,) = address(prarentContract).call{value:msg.value}(abi.encodeWithSignature("triggerPayment(uint256)", index));
         require(success, "Payment is not success");
    }
    
}

contract ItemManager is Ownable{
    
    
        enum SupplyChainState{
        Created, Paid, Delivered
    }
    
    struct itemRec{
        Item newItemContract ; //type of Item Contract to receive the address of the contract
        string identifier;
        uint itemPrice;
        SupplyChainState state; //this is enum type which returns the index value of that position starts from 0
        
    }
    
    //to store the created item in the contract
    mapping(uint => itemRec) public items;
    //uint itemIndex;

    event SupplyChainEvent(uint _itemIndex, uint _Supplystate, address _itemAddress);

/*Note - Below code works perfect     
but it using array(dynamic) so it cast more gas to reduce the gas price 
we are using mappping with struct attributes rather passing struct attributes into the array

*/  
/*    
    itemRec[] public _itemRec;
    
    //using this function create the item by mapping with in the struct
    function createItem(string memory _itemDescription, uint _itemPrice) public {
        itemRec memory newItem = itemRec ({
            itemDescription: _itemDescription,
            itemPrice : _itemPrice,
            state:SupplyChainState.Created
        });
        
        _itemRec.push(newItem);
        
    }
 */   
 
    //function created with mapping and struct combination to avoid array type as described above
    function createItem(uint itemIndex, string memory _identifier, uint _itemPrice) public OnlyOwner{
        //get the instance of Item contract and passed itemManager contract address as 'this' 
        //to receive that in the Item contract constructor
        Item _newItemContract = new Item(this,itemIndex,_itemPrice); 
        items[itemIndex].newItemContract = _newItemContract;
        items[itemIndex].identifier = _identifier;
        items[itemIndex].itemPrice = _itemPrice;
        items[itemIndex].state = SupplyChainState.Created;
        emit SupplyChainEvent(itemIndex, uint(items[itemIndex].state),address(_newItemContract));//type cast the enum with uint since it holds indexNumber on it.
        
        itemIndex++;
    }
    
    //item should pay only when item is created and payment should match with item price
    function triggerPayment(uint _itemIndex) public payable {
        require(items[_itemIndex].itemPrice == msg.value, 'Only full payment is accepted');
        require(items[_itemIndex].state == SupplyChainState.Created, "Items are not created yet");
       
        items[_itemIndex].state = SupplyChainState.Paid;
        emit SupplyChainEvent(_itemIndex, uint(items[_itemIndex].state),address(items[_itemIndex].newItemContract));

    }
    
    function triggerDelivery(uint _itemIndex) public OnlyOwner {
        require(items[_itemIndex].state == SupplyChainState.Paid, "Items further in the chain");
        items[_itemIndex].state = SupplyChainState.Delivered;
        
        emit SupplyChainEvent(_itemIndex, uint(items[_itemIndex].state),address(items[_itemIndex].newItemContract));
        
    }
    
}